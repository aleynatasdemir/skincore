#!/usr/bin/env python3
"""
Google Cloud Vision API ile ürün fotoğraflarından metin çıkarır
ve MongoDB'deki ilgili ürüne ocr_text alanı olarak yazar.

Klasör adı = gratis_id (veya barcode) → MongoDB eşleştirme bu ID ile yapılır.

Kullanım:
    pip install requests python-dotenv pymongo pillow
    python extract_text.py
"""

import os
import base64
import glob
import time
import requests
from io import BytesIO
from PIL import Image
from dotenv import load_dotenv
from bson import ObjectId
from pymongo import MongoClient

# ── Ayarlar ──────────────────────────────────────────────────────────────────
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

MONGO_URI = "mongodb://localhost:27017/"
DB_NAME = "kozmetik"
COL_NAME = "products"
IMAGES_DIR = os.path.join(os.path.dirname(__file__), "images")

MIN_IMAGE_SIZE = 300
MAX_IMAGE_SIDE = 2000
REQUEST_DELAY = 0.1
MAX_RETRIES = 3
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")
# ─────────────────────────────────────────────────────────────────────────────


def get_image_files(folder: str) -> list[str]:
    """Bir klasördeki geçerli ve yeterli boyuttaki resim dosyalarını döndürür."""
    files = []
    for ext in IMAGE_EXTENSIONS:
        files.extend(glob.glob(os.path.join(folder, f"*{ext}")))

    # 5KB altı muhtemelen placeholder
    files = [f for f in files if os.path.getsize(f) > 5000]

    valid = []
    for f in sorted(files):
        try:
            with Image.open(f) as img:
                w, h = img.size
                if w >= MIN_IMAGE_SIZE and h >= MIN_IMAGE_SIZE:
                    valid.append(f)
        except Exception:
            pass
    return valid[:2]


def image_to_base64(image_path: str) -> str | None:
    """Resmi yükle, küçült, base64 döndür."""
    try:
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            w, h = img.size
            if max(w, h) > MAX_IMAGE_SIDE:
                ratio = MAX_IMAGE_SIDE / max(w, h)
                img = img.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
            buf = BytesIO()
            img.save(buf, format="JPEG", quality=85)
            return base64.b64encode(buf.getvalue()).decode("utf-8")
    except Exception:
        return None


def extract_text_vision(api_url: str, image_paths: list[str]) -> str:
    """Google Cloud Vision API ile resimlerden metin çıkarır."""
    all_texts = []

    for img_path in image_paths:
        b64 = image_to_base64(img_path)
        if not b64:
            continue

        payload = {
            "requests": [{
                "image": {"content": b64},
                "features": [{"type": "TEXT_DETECTION"}]
            }]
        }

        for attempt in range(MAX_RETRIES):
            try:
                r = requests.post(api_url, json=payload, timeout=30)

                if r.status_code == 200:
                    data = r.json()
                    resp = data.get("responses", [{}])[0]

                    if "error" in resp:
                        break

                    annotations = resp.get("textAnnotations", [])
                    if annotations:
                        # İlk eleman tüm metni içerir
                        all_texts.append(annotations[0]["description"])
                    break

                elif r.status_code == 429:
                    time.sleep(30)
                else:
                    time.sleep(1)

            except Exception:
                time.sleep(1)

    return " ".join(all_texts).strip()


def main():
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("GOOGLE_API_KEY .env dosyasında bulunamadı!")
        return

    api_url = f"https://vision.googleapis.com/v1/images:annotate?key={api_key}"

    client = MongoClient(MONGO_URI)
    col = client[DB_NAME][COL_NAME]

    product_folders = sorted(
        d for d in os.listdir(IMAGES_DIR)
        if os.path.isdir(os.path.join(IMAGES_DIR, d))
    )

    total = len(product_folders)
    updated = 0
    skipped = 0
    no_image = 0
    no_doc = 0
    errors = 0

    print(f"Toplam klasör: {total}")
    print(f"Kaynak: {IMAGES_DIR}\n")

    for i, folder_name in enumerate(product_folders, 1):
        folder_path = os.path.join(IMAGES_DIR, folder_name)
        image_files = get_image_files(folder_path)

        if not image_files:
            no_image += 1
            continue

        # MongoDB'de ürünü bul
        query_conditions = [{"gratis_id": folder_name}, {"barcode": folder_name}]
        if ObjectId.is_valid(folder_name):
            query_conditions.append({"_id": ObjectId(folder_name)})
        doc = col.find_one(
            {"$or": query_conditions},
            {"_id": 1, "ocr_text": 1},
        )
        if not doc:
            no_doc += 1
            continue

        # Zaten ocr_text varsa atla
        if doc.get("ocr_text"):
            skipped += 1
            if i % 500 == 0:
                print(f"[{i}/{total}] ... {skipped} atlandı")
            continue

        # Vision API ile metin çıkar
        text = extract_text_vision(api_url, image_files)

        if text:
            col.update_one({"_id": doc["_id"]}, {"$set": {"ocr_text": text}})
            updated += 1
            if updated % 10 == 0:
                print(
                    f"[{i}/{total}] updated: {updated} | "
                    f"skipped: {skipped} | errors: {errors}"
                )
        else:
            errors += 1

        time.sleep(REQUEST_DELAY)

        if i % 100 == 0:
            print(
                f"\n--- ÖZET [{i}/{total}] ---  "
                f"updated: {updated} | skipped: {skipped} | "
                f"no_image: {no_image} | no_doc: {no_doc} | errors: {errors}\n"
            )

    client.close()
    print(f"\n{'='*50}")
    print(f"Tamamlandı!")
    print(f"  Güncellenen : {updated}")
    print(f"  Atlanan     : {skipped}")
    print(f"  Resim yok   : {no_image}")
    print(f"  DB'de yok   : {no_doc}")
    print(f"  Hata        : {errors}")


if __name__ == "__main__":
    main()
