#!/usr/bin/env python3
"""
MongoDB kozmetik/products koleksiyonundaki ürünlerin
fotoğraflarını indirip db_ocr/images/ klasörüne kaydeder.

Klasör yapısı: images/<gratis_id>/<fileName>
"""

import os
import time
import random
from curl_cffi import requests
from dotenv import load_dotenv
from pymongo import MongoClient
from concurrent.futures import ThreadPoolExecutor, as_completed

load_dotenv()
_env_proxies = os.environ.get("PROXIES", "")
# if proxies exist, we split by comma.
PROXIES = [p.strip() for p in _env_proxies.split(",")] if _env_proxies else []

# ── Ayarlar ──────────────────────────────────────────────────────────────────
MONGO_URI   = "mongodb://localhost:27017/"
DB_NAME     = "kozmetik"
COL_NAME    = "products"
OUTPUT_DIR  = os.path.join(os.path.dirname(__file__), "images")
MAX_WORKERS = 10          # curl_cffi + proxy olunca paralellik arttırılabilir
TIMEOUT     = 15          # saniye
SKIP_EXISTING = True      # zaten indirilmiş dosyaları atla
MAX_IMAGES_PER_PRODUCT = 2  # ürün başına max fotoğraf sayısı
MAX_RETRIES = 3           # başarısız indirmelerde tekrar deneme sayısı
# ─────────────────────────────────────────────────────────────────────────────

def normalize_url(url: str) -> str:
    url = url.strip()
    if url.startswith("//"):
        return "https:" + url
    return url

def get_ext(url: str, default_ext=".jpg") -> str:
    """Ekstra parametreleri atarak makul bir uzantı bulur."""
    base = url.split("?")[0].split("/")[-1]
    if "." in base:
        ext = "." + base.split(".")[-1].lower()
        if len(ext) <= 5 and ext.isalnum() == False:  # basit sanity
            return ext
    return default_ext

def download_image(task):
    """Tek bir resmi indir. task = (gratis_id, barcode, fileUrl, fileName)"""
    gratis_id, barcode, file_url, file_name = task

    # Sadece belli formatı destekle, filename gibi URL verilerini filtrele
    if not file_url.startswith(("http://", "https://")):
        return ("skip", "geçersiz url")

    # Klasör: images/<gratis_id>/
    folder_id = gratis_id or barcode or "unknown"
    folder = os.path.join(OUTPUT_DIR, str(folder_id))
    os.makedirs(folder, exist_ok=True)

    dest = os.path.join(folder, file_name)

    if SKIP_EXISTING and os.path.exists(dest):
        return ("skip", file_name)

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            proxy_url = random.choice(PROXIES) if PROXIES else None
            proxies = {"http": proxy_url, "https": proxy_url} if proxy_url else None
            
            resp = requests.get(
                file_url,
                impersonate="chrome110",
                timeout=TIMEOUT,
                proxies=proxies,
                stream=True
            )
            resp.raise_for_status()
            
            with open(dest, "wb") as f:
                for chunk in resp.iter_content(8192):
                    if chunk:
                        f.write(chunk)
            
            # İstekler arası çok hafif bekleme
            time.sleep(random.uniform(0.1, 0.5))
            return ("ok", file_name)
        except Exception as e:
            if attempt < MAX_RETRIES:
                time.sleep(attempt * 2 + random.uniform(0.5, 2))
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
    skip_cnt = 0
    cursor = col.find({}, {"gratis_id": 1, "barcode": 1, "image_urls": 1})
    for doc in cursor:
        gratis_id = doc.get("gratis_id", "")
        barcode   = doc.get("barcode", "")
        
        folder_id = str(gratis_id or barcode or "unknown")
        folder = os.path.join(OUTPUT_DIR, folder_id)

        # Klasördeki mevcut resim sayısını al (eski uzun isimliler dahil)
        existing_imgs = 0
        if SKIP_EXISTING and os.path.exists(folder):
            existing_imgs = len([
                f for f in os.listdir(folder)
                if os.path.isfile(os.path.join(folder, f)) and 
                   f.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
            ])
            
        seen = set()
        count = 0
        for img in doc.get("image_urls", []):
            if count >= MAX_IMAGES_PER_PRODUCT:
                break
                
            # Bazı belgeler dict, bazıları direk string URL
            if isinstance(img, dict):
                file_url  = img.get("fileUrl", "")
            elif isinstance(img, str):
                file_url  = img
            else:
                continue
                
            file_url = normalize_url(file_url)
            if not file_url.startswith(("http://", "https://")):
                continue
                
            if file_url in seen:
                continue
                
            seen.add(file_url)
            # İsim olarak sade 0.jpg, 1.jpg vs. yapalım
            ext = get_ext(file_url)
            file_name = f"{count}{ext}"    

            if file_url:
                dest = os.path.join(folder, file_name)
                # Zaten indirildiyse (dosya var VEYA klasördeki mevcut resim sayısı count'tan büyükse) atla
                if SKIP_EXISTING and (os.path.exists(dest) or existing_imgs > count):
                    skip_cnt += 1
                else:
                    tasks.append((gratis_id, barcode, file_url, file_name))
                count += 1

    client.close()

    total   = len(tasks)
    ok_cnt  = 0
    err_cnt = 0

    print(f"Toplam indirme görevi oluşturuldu: {total}")
    print(f"Başlangıçta zaten var olan (atlanan) resim sayısı: {skip_cnt}")
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
