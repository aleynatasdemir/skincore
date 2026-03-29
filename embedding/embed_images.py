#!/usr/bin/env python3
"""
Ürün fotoğraflarından Gemini Embedding API (REST) ile vektör çıkarır
ve MongoDB'deki ilgili ürüne `embedding` alanı olarak yazar.

Kullanım:
    pip install requests python-dotenv pymongo pillow
    python embed_images.py
"""

import os
import sys
import time
import glob
import base64
import requests
from io import BytesIO
from PIL import Image
from dotenv import load_dotenv
from pymongo import MongoClient, UpdateOne
from bson import ObjectId
from typing import Optional, Union, List, Dict, Any

# ── Ayarlar ──────────────────────────────────────────────────────────────────
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

MONGO_URI = "mongodb://localhost:27017/"
DB_NAME = "kozmetik"
COL_NAME = "products"
IMAGES_DIR = os.path.join(os.path.dirname(__file__), "..", "db_ocr", "images")
MODEL = "gemini-embedding-2-preview"
BATCH_SIZE = 100            # Google API sınırı
MAX_IMAGE_SIDE = 512        # resmi küçült (hız + boyut)
MAX_IMAGE_MB = 4
REQUEST_DELAY = 1.0         # Batch sonrası biraz bekle
MAX_RETRIES = 3
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")
# ─────────────────────────────────────────────────────────────────────────────


def get_best_image(folder: str) -> Optional[str]:
    """Klasördeki en büyük (dosya boyutu) resmi döndürür."""
    files = []
    for ext in IMAGE_EXTENSIONS:
        files.extend(glob.glob(os.path.join(folder, f"*{ext}")))
    if not files:
        return None
    return max(files, key=os.path.getsize)


def process_image(image_path: str) -> tuple[Optional[str], Optional[str]]:
    """Resmi yükle, küçült, base64 döndür."""
    try:
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            img.thumbnail((MAX_IMAGE_SIDE, MAX_IMAGE_SIDE))

            buf = BytesIO()
            img.save(buf, format="JPEG", quality=85)
            data = buf.getvalue()

            if len(data) > MAX_IMAGE_MB * 1024 * 1024:
                return None, "image_too_large"

            return base64.b64encode(data).decode("utf-8"), None
    except Exception:
        return None, "image_corrupted"


def get_embeddings_batch(api_url: str, images_b64: List[str]) -> List[Optional[List[float]]]:
    """batchEmbedContents ile toplu embedding al."""
    requests_list = []
    for b64 in images_b64:
        requests_list.append({
            "model": f"models/{MODEL}",
            "content": {
                "parts": [{
                    "inlineData": {
                        "mimeType": "image/jpeg",
                        "data": b64
                    }
                }]
            }
        })

    payload = {"requests": requests_list}

    for attempt in range(MAX_RETRIES):
        try:
            r = requests.post(
                api_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=120
            )

            if r.status_code == 200:
                data = r.json()
                if "embeddings" in data:
                    return [e.get("values") for e in data["embeddings"]]
                return [None] * len(images_b64)
            elif r.status_code == 429:
                print(f"  Rate limit (429), {60 * (attempt + 1)}s bekleniyor...")
                time.sleep(60 * (attempt + 1))
            else:
                print(f"  API Hata: {r.status_code} - 5s bekleniyor...")
                time.sleep(5)
        except Exception as e:
            print(f"  Exception: {e} - 5s bekleniyor...")
            time.sleep(5)

    return [None] * len(images_b64)


def find_product(col, folder_name: str):
    """Klasör adına göre MongoDB'de ürünü bul."""
    conditions = [{"gratis_id": folder_name}, {"barcode": folder_name}]
    if ObjectId.is_valid(folder_name):
        conditions.append({"_id": ObjectId(folder_name)})
    return col.find_one({"$or": conditions}, {"_id": 1, "embedding": 1})


def main():
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("GOOGLE_API_KEY .env dosyasında bulunamadı!")
        sys.exit(1)

    batch_url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:batchEmbedContents?key={api_key}"

    client_mongo = MongoClient(MONGO_URI)
    col = client_mongo[DB_NAME][COL_NAME]

    product_folders = sorted(
        d for d in os.listdir(IMAGES_DIR)
        if os.path.isdir(os.path.join(IMAGES_DIR, d))
    )

    total = len(product_folders)
    embedded = 0
    skipped = 0
    no_image = 0
    no_doc = 0
    errors = 0

    print(f"Toplam klasor: {total}")
    print(f"Kaynak: {IMAGES_DIR}\n")

    current_batch_images = []
    current_batch_ids = []

    def flush_batch():
        nonlocal embedded, errors
        if not current_batch_images:
            return

        print(f"  -> Batch gönderiliyor ({len(current_batch_images)} resim)...")
        vectors = get_embeddings_batch(batch_url, current_batch_images)

        bulk_ops = []
        for doc_id, vector in zip(current_batch_ids, vectors):
            if vector:
                bulk_ops.append(UpdateOne({"_id": doc_id}, {"$set": {"embedding": vector}}))
                embedded += 1
            else:
                errors += 1

        if bulk_ops:
            col.bulk_write(bulk_ops)

        current_batch_images.clear()
        current_batch_ids.clear()
        time.sleep(REQUEST_DELAY)

    for i, folder_name in enumerate(product_folders, 1):
        folder_path = os.path.join(IMAGES_DIR, folder_name)

        # MongoDB'de ürünü bul (Önce kontrol et ki resmi boşuna işlemeyelim)
        doc = find_product(col, folder_name)
        if not doc:
            no_doc += 1
            continue

        if doc.get("embedding"):
            skipped += 1
            if i % 1000 == 0:
                print(f"[{i}/{total}] ... {skipped} atlandı")
            continue

        # En iyi resmi seç
        image_path = get_best_image(folder_path)
        if not image_path:
            no_image += 1
            continue

        # Resmi işle
        image_b64, reason = process_image(image_path)
        if not image_b64:
            errors += 1
            print(f"[{i}/{total}] SKIP {folder_name}: {reason}")
            continue

        current_batch_images.append(image_b64)
        current_batch_ids.append(doc["_id"])

        if len(current_batch_images) >= BATCH_SIZE:
            flush_batch()
            print(f"[{i}/{total}] embedded: {embedded} | skipped: {skipped} | errors: {errors}")

    # Kalanları temizle
    flush_batch()

    client_mongo.close()
    print(f"\n{'='*50}")
    print(f"Tamamlandi!")
    print(f"  Embedded  : {embedded}")
    print(f"  Atlanan   : {skipped}")
    print(f"  Resim yok : {no_image}")
    print(f"  DB'de yok : {no_doc}")
    print(f"  Hata      : {errors}")


if __name__ == "__main__":
    main()
