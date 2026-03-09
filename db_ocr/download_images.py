#!/usr/bin/env python3
"""
MongoDB local/production koleksiyonundaki ürünlerin
fotoğraflarını indirip db_ocr/images/ klasörüne kaydeder.

Klasör yapısı: images/<gratis_id>/<fileName>
"""

import os
import time
import random
import requests
from pymongo import MongoClient
from concurrent.futures import ThreadPoolExecutor, as_completed

# ── Ayarlar ──────────────────────────────────────────────────────────────────
MONGO_URI   = "mongodb://localhost:27017/"
DB_NAME     = "local"
COL_NAME    = "production"
OUTPUT_DIR  = os.path.join(os.path.dirname(__file__), "images")
MAX_WORKERS = 5           # paralel indirme sayısı (ban yememek için düşük)
TIMEOUT     = 10          # saniye
SKIP_EXISTING = True      # zaten indirilmiş dosyaları atla
MAX_IMAGES_PER_PRODUCT = 2  # ürün başına max fotoğraf sayısı
MAX_RETRIES = 1           # başarısız indirmelerde tekrar deneme sayısı
# ─────────────────────────────────────────────────────────────────────────────

HEADERS_BASE = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Sec-Fetch-Dest": "image",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Site": "cross-site",
}

USER_AGENTS = [
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0",
]

def download_image(task):
    """Tek bir resmi indir. task = (gratis_id, barcode, fileUrl, fileName)"""
    gratis_id, barcode, file_url, file_name = task

    # Klasör: images/<gratis_id>/
    folder_id = gratis_id or barcode or "unknown"
    folder = os.path.join(OUTPUT_DIR, str(folder_id))
    os.makedirs(folder, exist_ok=True)

    dest = os.path.join(folder, file_name)

    if SKIP_EXISTING and os.path.exists(dest):
        return ("skip", file_name)

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            # Her istekte yeni session (cookie birikmesini önler)
            headers = {**HEADERS_BASE, "User-Agent": random.choice(USER_AGENTS)}
            resp = requests.get(file_url, headers=headers, timeout=TIMEOUT, stream=True)
            resp.raise_for_status()
            with open(dest, "wb") as f:
                for chunk in resp.iter_content(8192):
                    f.write(chunk)
            # İstekler arası rastgele bekleme (ban önleme)
            time.sleep(random.uniform(0.1, 0.5))
            return ("ok", file_name)
        except Exception as e:
            if attempt < MAX_RETRIES:
                time.sleep(attempt * 3 + random.uniform(1, 3))
            else:
                return ("err", f"{file_name} -> {e}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    client = MongoClient(MONGO_URI)
    col = client[DB_NAME][COL_NAME]
    total_docs = col.count_documents({})
    print(f"Toplam ürün: {total_docs}")

    # Tüm görevleri hazırla
    tasks = []
    cursor = col.find({}, {"gratis_id": 1, "barcode": 1, "image_urls": 1})
    for doc in cursor:
        gratis_id = doc.get("gratis_id", "")
        barcode   = doc.get("barcode", "")
        for i, img in enumerate(doc.get("image_urls", [])[:MAX_IMAGES_PER_PRODUCT]):
            # Bazı belgeler dict, bazıları direk string URL
            if isinstance(img, dict):
                file_url  = img.get("fileUrl", "")
                file_name = img.get("fileName", "") or file_url.split("/")[-1]
            elif isinstance(img, str):
                file_url  = img
                file_name = img.split("/")[-1] or f"{gratis_id or barcode}_{i}.jpg"
            else:
                continue
            if file_url and file_name:
                tasks.append((gratis_id, barcode, file_url, file_name))

    client.close()

    total   = len(tasks)
    ok_cnt  = 0
    err_cnt = 0
    skip_cnt= 0

    print(f"Toplam indirme görevi: {total}")
    print(f"Klasör: {OUTPUT_DIR}\n")

    start = time.time()
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(download_image, t): t for t in tasks}
        for i, fut in enumerate(as_completed(futures), 1):
            status, msg = fut.result()
            if status == "ok":
                ok_cnt += 1
            elif status == "skip":
                skip_cnt += 1
            else:
                err_cnt += 1
                print(f"  ⚠️  HATA: {msg}")

            # Her 100 görevde ilerleme göster
            if i % 100 == 0 or i == total:
                elapsed = time.time() - start
                rate = i / elapsed if elapsed > 0 else 0
                remaining = (total - i) / rate if rate > 0 else 0
                print(
                    f"[{i}/{total}] ✅ {ok_cnt} indirildi | "
                    f"⏭️  {skip_cnt} atlandı | ❌ {err_cnt} hata | "
                    f"hız: {rate:.1f}/s | kalan: {remaining:.0f}s"
                )

    elapsed = time.time() - start
    print(f"\n✨ Tamamlandı!")
    print(f"   İndirilen : {ok_cnt}")
    print(f"   Atlanan   : {skip_cnt}")
    print(f"   Hata      : {err_cnt}")
    print(f"   Süre      : {elapsed:.1f} saniye")
    print(f"   Klasör    : {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
