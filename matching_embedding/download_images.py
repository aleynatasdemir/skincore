import pandas as pd
import os
import time
import random
from curl_cffi import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlparse
import math

# Configuration
EXCEL_FILE = '/Users/aleyna/Desktop/embedding/watsons-essence-com-tr-2026-03-14.csv'
EMBEDDING_DIR = '/Users/aleyna/Desktop/embedding/essence_wats_img'
MAX_WORKERS = 10
TIMEOUT = 15
MAX_RETRIES = 3

def get_ext(url: str, default_ext=".png") -> str:
    if not url or not isinstance(url, str): return default_ext
    base = url.split("?")[0].split("/")[-1]
    if "." in base:
        parts = base.split(".")
        ext = "." + parts[-1].lower()
        if len(ext) <= 5: return ext
    return default_ext

def download_image(task):
    identifier, url, dest = task
    if not url or pd.isna(url):
        return ("skip", "no url")
    
    if os.path.exists(dest):
        return ("skip", os.path.basename(dest))

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, impersonate="chrome110", timeout=TIMEOUT, stream=True)
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
    print(f"Reading {EXCEL_FILE}...")
    try:
        df = pd.read_csv(EXCEL_FILE)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    os.makedirs(EMBEDDING_DIR, exist_ok=True)
    
    tasks = []
    for _, row in df.iterrows():
        item_link = row.get('item_page_link')
        
        identifier = None
        if pd.notna(item_link) and isinstance(item_link, str):
            # Example URL: https://www.watsons.com.tr/essence-jel-oje-no-46/p/BP_1327319
            if '/p/BP_' in item_link:
                identifier = item_link.split('/p/BP_')[-1].split('?')[0].strip('/')
            elif '/p/' in item_link:
                identifier = item_link.split('/p/')[-1].split('?')[0].strip('/')
                
        # Fallback if URL parsing failed or didn't contain an ID
        if not identifier:
            raw_id = row.get('web_scraper_order')
            if pd.notna(raw_id):
                if isinstance(raw_id, float) and not math.isnan(raw_id):
                    identifier = str(int(raw_id))
                else:
                    identifier = str(raw_id).strip()
            
        if not identifier:
            continue
            
        url = None
        # Try multiple url columns based on observation
        for col in ['image', 'image_1', 'image2', 'image3']:
            col_val = row.get(col)
            if pd.notna(col_val) and isinstance(col_val, str) and col_val.startswith('http'):
                url = col_val
                break
                
        if not url:
            continue
            
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
