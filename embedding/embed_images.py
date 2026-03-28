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
from pymongo import MongoClient
from bson import ObjectId

# ── Ayarlar ──────────────────────────────────────────────────────────────────
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

MONGO_URI = "mongodb://localhost:27017/"
DB_NAME = "kozmetik"
COL_NAME = "products"
IMAGES_DIR = os.path.join(os.path.dirname(__file__), "..", "db_ocr", "images")
MODEL = "gemini-embedding-2-preview"
MAX_IMAGE_SIDE = 512        # resmi küçült (hız + boyut)
MAX_IMAGE_MB = 4
REQUEST_DELAY = 0.25
MAX_RETRIES = 3
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")
# ─────────────────────────────────────────────────────────────────────────────


def get_best_image(folder: str) -> str | None:
    """Klasördeki en büyük (dosya boyutu) resmi döndürür."""
    files = []
    for ext in IMAGE_EXTENSIONS:
        files.extend(glob.glob(os.path.join(folder, f"*{ext}")))
    if not files:
        return None
    return max(files, key=os.path.getsize)


def process_image(image_path: str) -> tuple[str | None, str | None]:
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


def get_embedding(api_url: str, image_b64: str) -> list[float] | None:
    """REST API ile embedding al."""
    payload = {
        "model": f"models/{MODEL}",
        "content": {
            "parts": [{
                "inlineData": {
                    "mimeType": "image/jpeg",
                    "data": image_b64
                }
            }]
        }
    }

    for attempt in range(MAX_RETRIES):
        try:
            r = requests.post(
                api_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=60
            )

            if r.status_code == 200:
                data = r.json()
                if "embedding" in data:
                    return data["embedding"]["values"]
                return None
            elif r.status_code == 429:
                print("  Rate limit, 30s bekleniyor...")
                time.sleep(30)
            else:
                time.sleep(1)
        except Exception:
            time.sleep(1)

    return None


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

    api_url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:embedContent?key={api_key}"

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

    for i, folder_name in enumerate(product_folders, 1):
        folder_path = os.path.join(IMAGES_DIR, folder_name)

        # En iyi resmi seç
        image_path = get_best_image(folder_path)
        if not image_path:
            no_image += 1
            continue

        # MongoDB'de ürünü bul
        doc = find_product(col, folder_name)
        if not doc:
            no_doc += 1
            continue

        # Zaten embedding varsa atla
        if doc.get("embedding"):
            skipped += 1
            if i % 500 == 0:
                print(f"[{i}/{total}] ... {skipped} atlandı")
            continue

        # Resmi işle
        image_b64, reason = process_image(image_path)
        if not image_b64:
            errors += 1
            print(f"[{i}/{total}] SKIP {folder_name}: {reason}")
            continue

        # Embedding al
        vector = get_embedding(api_url, image_b64)

        if vector:
            col.update_one(
                {"_id": doc["_id"]},
                {"$set": {"embedding": vector}},
            )
            embedded += 1

            if embedded % 10 == 0:
                print(
                    f"[{i}/{total}] embedded: {embedded} | "
                    f"skipped: {skipped} | errors: {errors}"
                )
        else:
            errors += 1
            print(f"[{i}/{total}] API HATA {folder_name}")

        time.sleep(REQUEST_DELAY)

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
