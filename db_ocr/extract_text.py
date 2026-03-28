#!/usr/bin/env python3
"""
PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True python3 extract_text.py 




db_ocr/images/ klasöründeki ürün fotoğraflarından PaddleOCR ile
metin çıkarır ve MongoDB local/production koleksiyonundaki ilgili
ürüne  ocr_text  alanı olarak yazar.

Klasör adı = gratis_id  (veya barcode) → MongoDB eşleştirme bu ID ile yapılır.

Kullanım:
    pip install paddlepaddle paddleocr pymongo
    python extract_text.py
"""

import os
import gc
import glob
import numpy as np
from PIL import Image
import pillow_heif
from bson import ObjectId
from paddleocr import PaddleOCR
from pymongo import MongoClient

# Pillow can now open AVIF/HEIF
pillow_heif.register_heif_opener()

MIN_IMAGE_SIZE = 300  # piksel (genişlik veya yükseklik bu altındaysa atla)
MAX_IMAGE_SIZE = 4000  # bu pikselden büyük resimleri atla (RAM koruması)

# ── Ayarlar ──────────────────────────────────────────────────────────────────
MONGO_URI  = "mongodb://localhost:27017/"
DB_NAME    = "kozmetik"
COL_NAME   = "products"
IMAGES_DIR = os.path.join(os.path.dirname(__file__), "images")
# ─────────────────────────────────────────────────────────────────────────────

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")


def get_image_files(folder: str) -> list[str]:
    """Bir klasördeki geçerli ve yeterli boyuttaki resim dosyalarını döndürür."""
    files = []
    for ext in IMAGE_EXTENSIONS:
        files.extend(glob.glob(os.path.join(folder, f"*{ext}")))

    # Dosya boyutu ile hızlı ön filtre (5KB altı muhtemelen placeholder)
    files = [f for f in files if os.path.getsize(f) > 5000]

    # Küçük thumbnail'leri ve aşırı büyük dosyaları filtrele
    valid = []
    for f in sorted(files):
        try:
            # Sadece header oku, tüm resmi belleğe yükleme
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
            with Image.open(img_path) as img:
                img_rgb = img.convert("RGB")
                # Büyük resimleri küçült — RAM koruması
                max_side = 2000
                w, h = img_rgb.size
                if max(w, h) > max_side:
                    ratio = max_side / max(w, h)
                    img_rgb = img_rgb.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
                np_img = np.array(img_rgb)
                # PIL image'ı hemen kapat
                del img_rgb

            # RGB -> BGR
            np_img = np_img[:, :, ::-1]

            result = ocr.predict(np_img)
            del np_img

            for item in result:
                rec_texts = item.get("rec_texts", [])
                if rec_texts:
                    all_texts.extend(rec_texts)
            del result
            gc.collect()
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

        # MongoDB'de ürünü bul: gratis_id, barcode veya _id ile eşleştir
        query_conditions = [{"gratis_id": folder_name}, {"barcode": folder_name}]
        if ObjectId.is_valid(folder_name):
            query_conditions.append({"_id": ObjectId(folder_name)})
        doc = col.find_one(
            {"$or": query_conditions},
            {"_id": 1, "ocr_text": 1},
        )
        if not doc:
            no_doc += 1
            print(f"[{i}/{total}] ❌ {folder_name} → MongoDB'de bulunamadı")
            continue

        # Zaten ocr_text varsa atla (kaldığı yerden devam)
        if doc.get("ocr_text"):
            skipped += 1
            print(f"[{i}/{total}] ⏩ {folder_name} → zaten var, atlandı")
            continue

        # OCR ile metin çıkar
        text = extract_text_from_images(ocr, image_files)

        if text:
            col.update_one({"_id": doc["_id"]}, {"$set": {"ocr_text": text}})
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
