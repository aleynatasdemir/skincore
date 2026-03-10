#!/usr/bin/env python3
"""
db_ocr/images/ klasöründeki ürün fotoğraflarından PaddleOCR ile
metin çıkarır ve MongoDB local/production koleksiyonundaki ilgili
ürüne  image_text  alanı olarak yazar.

Klasör adı = gratis_id  (veya barcode) → MongoDB eşleştirme bu ID ile yapılır.

Kullanım:
    pip install paddlepaddle paddleocr pymongo
    python extract_text.py
"""

import os
import glob
from PIL import Image
from paddleocr import PaddleOCR
from pymongo import MongoClient

MIN_IMAGE_SIZE = 300  # piksel (genişlik veya yükseklik bu altındaysa atla)

# ── Ayarlar ──────────────────────────────────────────────────────────────────
MONGO_URI  = "mongodb://localhost:27017/"
DB_NAME    = "local"
COL_NAME   = "production"
IMAGES_DIR = os.path.join(os.path.dirname(__file__), "images")
# ─────────────────────────────────────────────────────────────────────────────

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")


def get_image_files(folder: str) -> list[str]:
    """Bir klasördeki geçerli ve yeterli boyuttaki resim dosyalarını döndürür."""
    files = []
    for ext in IMAGE_EXTENSIONS:
        files.extend(glob.glob(os.path.join(folder, f"*{ext}")))

    # Küçük thumbnail'leri ve bozuk dosyaları filtrele
    valid = []
    for f in sorted(files):
        try:
            with Image.open(f) as img:
                w, h = img.size
                if w >= MIN_IMAGE_SIZE and h >= MIN_IMAGE_SIZE:
                    valid.append(f)
        except Exception:
            pass  # bozuk/okunamayan dosyayı atla
    return valid[:2]


def extract_text_from_images(ocr: PaddleOCR, image_paths: list[str]) -> str:
    """Birden fazla resimden OCR ile metin çıkarır, birleştirip döndürür."""
    all_texts = []
    for img_path in image_paths:
        try:
            result = ocr.predict(img_path)
            for item in result:
                rec_texts = item.get("rec_texts", [])
                if rec_texts:
                    all_texts.extend(rec_texts)
        except Exception as e:
            print(f"  ⚠️  OCR hatası ({os.path.basename(img_path)}): {e}")
    return " ".join(all_texts).strip()


def main():
    # PaddleOCR: çok dilli (Türkçe + İngilizce + Latin)
    ocr = PaddleOCR(use_textline_orientation=True, lang="en")

    client = MongoClient(MONGO_URI)
    col = client[DB_NAME][COL_NAME]

    # Resim bulunan klasörleri listele
    product_folders = sorted(
        d for d in os.listdir(IMAGES_DIR)
        if os.path.isdir(os.path.join(IMAGES_DIR, d))
    )

    total = len(product_folders)
    updated = 0
    skipped = 0
    no_image = 0
    no_doc = 0

    print(f"Toplam klasör: {total}")
    print(f"Kaynak: {IMAGES_DIR}\n")

    for i, folder_name in enumerate(product_folders, 1):
        folder_path = os.path.join(IMAGES_DIR, folder_name)
        image_files = get_image_files(folder_path)

        if not image_files:
            no_image += 1
            print(f"[{i}/{total}] ⏭️  {folder_name} → resim yok")
            continue

        # MongoDB'de ürünü bul: gratis_id veya barcode ile eşleştir
        doc = col.find_one(
            {"$or": [{"gratis_id": folder_name}, {"barcode": folder_name}]},
            {"_id": 1, "image_text": 1},
        )
        if not doc:
            no_doc += 1
            print(f"[{i}/{total}] ❌ {folder_name} → MongoDB'de bulunamadı")
            continue

        # Zaten image_text varsa atla (kaldığı yerden devam)
        if doc.get("image_text"):
            skipped += 1
            print(f"[{i}/{total}] ⏩ {folder_name} → zaten var, atlandı")
            continue

        # OCR ile metin çıkar
        text = extract_text_from_images(ocr, image_files)

        if text:
            col.update_one({"_id": doc["_id"]}, {"$set": {"image_text": text}})
            updated += 1
            print(f"[{i}/{total}] ✅ {folder_name} → {len(text)} karakter yazıldı")
        else:
            skipped += 1
            print(f"[{i}/{total}] ⚠️  {folder_name} → OCR boş döndü")

        # Özet (her 100'de)
        if i % 100 == 0:
            print(
                f"\n--- ÖZET [{i}/{total}] ---  "
                f"✅ {updated} | ⏭️ {skipped} | 📭 {no_image} | ❌ {no_doc}\n"
            )

    client.close()
    print(f"\n{'='*50}")
    print(f"Tamamlandı!")
    print(f"  ✅ Güncellenen ürün : {updated}")
    print(f"  ⏭️  Atlanan          : {skipped}")
    print(f"  📭 Resim yok        : {no_image}")
    print(f"  ❌ MongoDB'de yok   : {no_doc}")


if __name__ == "__main__":
    main()
