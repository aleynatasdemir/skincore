import pandas as pd
import os
import time
import random
from curl_cffi import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
CSV_FILE = '/Users/aleyna/Desktop/embedding/ewg-org-loreal-2026-03-14-2.csv'
EMBEDDING_DIR = '/Users/aleyna/Desktop/embedding/loreal_ewg_img'
MAX_WORKERS = 10
TIMEOUT = 15
MAX_RETRIES = 3

def get_ext(url: str, default_ext=".jpg") -> str:
    if not url or not isinstance(url, str): return default_ext
    base = url.split("?")[0].split("/")[-1]
    if "." in base:
        parts = base.split(".")
        ext = "." + parts[-1].lower()
        if len(ext) <= 5 and ext != ".": 
            return ext
    return default_ext

def download_image(task):
    identifier, url, dest = task
    
    if os.path.exists(dest):
        return ("skip", os.path.basename(dest))

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://www.ewg.org/"
    }

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, impersonate="chrome120", headers=headers, timeout=TIMEOUT, stream=True)
            resp.raise_for_status()
            with open(dest, "wb") as f:
                for chunk in resp.iter_content(8192):
                    if chunk: f.write(chunk)
            time.sleep(random.uniform(0.05, 0.15))
            return ("ok", os.path.basename(dest))
        except Exception as e:
            if attempt < MAX_RETRIES:
                time.sleep(attempt * 2 + random.uniform(0.5, 1))
            else:
                return ("err", f"{identifier} -> {e}")

def main():
    print(f"Reading {CSV_FILE}...")
    try:
        df = pd.read_csv(CSV_FILE)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    os.makedirs(EMBEDDING_DIR, exist_ok=True)

    tasks = []
    seen_ids = set()
    
    for _, row in df.iterrows():
        raw_id = row.get('web_scraper_order')
        if pd.isna(raw_id):
            continue
            
        identifier = str(raw_id).strip()
        if not identifier or identifier in seen_ids:
            continue
            
        url = None
        # İlk fotoğraf sütunu: 'image'
        col_val = row.get('image')
        if pd.notna(col_val) and isinstance(col_val, str) and col_val.startswith('http'):
            url = col_val
                
        if not url:
            continue
            
        # 'sd_logo.png' içerenleri atla (varsayılan missing_image logosu)
        if 'sd_logo.png' in url:
            continue
            
        seen_ids.add(identifier)
        
        ext = get_ext(url)
        dest = os.path.join(EMBEDDING_DIR, f"{identifier}{ext}")
        tasks.append((identifier, url, dest))

    print(f"Starting downloads for {len(tasks)} images using {MAX_WORKERS} workers...")
    
    ok_cnt, skip_cnt, err_cnt = 0, 0, 0
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(download_image, t): t for t in tasks}
        for i, fut in enumerate(as_completed(futures), 1):
            status, msg = fut.result()
            if status == "ok": ok_cnt += 1
            elif status == "skip": skip_cnt += 1
            else:
                err_cnt += 1
                if err_cnt < 20: print(f"  ⚠️  HATA: {msg}")

            if i % 100 == 0 or i == len(tasks):
                elapsed = time.time() - start_time
                print(f"[{i}/{len(tasks)}] ✅ {ok_cnt} indirildi | ⏭️  {skip_cnt} atlandı | ❌ {err_cnt} hata")

    print(f"\n✨ Tamamlandı! Süre: {time.time() - start_time:.1f}s")

if __name__ == "__main__":
    main()
