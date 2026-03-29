import json
import time
import sys
import threading
import random
from curl_cffi import requests as requests_cffi
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional
from urllib.parse import quote
import hmac
import hashlib
from datetime import datetime

class RateLimitError(Exception):
    """Custom exception for 429 Too Many Requests"""
    pass

# Configuration
BEARER_TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IkE4YmYifQ.eyJleHAiOjE3NzQyODA0NDUsImp0aSI6ImJhZTE3MjQyMzFjNDQ4YTBiOGFkNDVkYTVhMTZhMDQ3IiwiaWRlbnRpdHkiOjg4NzYwNzMsInByb3BlcnRpZXMiOnsidCI6MSwiYSI6bnVsbH0sInR5cGUiOjB9.Hl6x_nubyjiyEHyerMgztQ7U3mWYabRU3CBWnMRfabw"
BASE_URL = "https://api.onskin.com/api/mobile/v0.2"
INPUT_FILE = "missing_makeup_in_db.json"
OUTPUT_FILE = "onskin_barcode_results.jsonl"
EXISTING_RESULTS_FILE = "onskin_barcode_results.jsonl"

# Signature Configuration (Dynamic)
SIGN_KEY_HEX = "3079414a533c3f485460684b493d476e40645b4f5873445d4d524c32423e633b467267564351776139707531596937765778507462663435455c6a6b5538713a"
SIGN_SALT = "8aV8.H^QCl?+tbl="

# Token Refresh Configuration
REFRESH_TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IkE4YmYifQ.eyJleHAiOjE4MDU3NjIxNjEsImp0aSI6IjkwY2RhMGRhYWM1ZjQxMjg4YjhjZmJmZjY3N2Y5NjNiIiwiaWRlbnRpdHkiOjg4NzYwNzMsInByb3BlcnRpZXMiOnsidCI6MSwiYSI6bnVsbH0sInR5cGUiOjF9.VGkO_WUNYyLS1lTp_lWmlPBWrwXYAVpBJnNix-uXp3o"
REFRESH_KEY_ID = "rsNcVOTq"

# Rate limiting settings
REQUEST_DELAY = 15.0  # Increased for single IP use
RATE_LIMIT_BACKOFF = 300  # 5 minutes backoff for main IP 429

HEADERS = {
    'Host': 'api.onskin.com',
    'Connection': 'keep-alive',
    'Accept': '*/*',
    'User-Agent': 'OnSkin/3.20 (app.cosmetic; build:3.20.401.0; iOS 17.4.1) Alamofire/5.9.1',
    'Accept-Language': 'tr-TR;q=1.0, en-TR;q=0.9, nl-TR;q=0.8',
    'Authorization': f'Bearer {BEARER_TOKEN}'
}

class OnSkinFetcher:
    def __init__(self, num_workers: int = 1, proxy_file: str = None):
        self.num_workers = num_workers
        self.output_file = None
        self.processed_barcodes = set()
        self.bearer_token = BEARER_TOKEN
        self.token_expired = False
        self.proxies = []
        self.failed_proxies = set()  # Track failed proxies
        self.proxy_cooldowns = {}  # {proxy_url: timestamp_when_available}
        self.stats = {
            'total': 0,
            'found_by_barcode': 0,
            'found_by_search': 0,
            'not_found': 0,
            'errors': 0,
            'skipped': 0,
            'started': 0
        }
        # Thread-safety locks
        self.stats_lock = threading.Lock()
        self.file_lock = threading.Lock()
        self.processed_lock = threading.Lock()
        self.token_lock = threading.Lock()
        self.proxy_lock = threading.Lock()

        # Load proxies if provided
        if proxy_file:
            self.load_proxies(proxy_file)

    def load_proxies(self, proxy_file: str):
        """Load proxies from file"""
        try:
            with open(proxy_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        self.proxies.append(line)
            if self.proxies:
                print(f"✓ Loaded {len(self.proxies)} proxies")
        except Exception as e:
            print(f"⚠ Error loading proxies: {e}")

    def get_random_proxy(self, exclude: set = None) -> Optional[str]:
        """Get random proxy from list, excluding failed ones (thread-safe)"""
        if not self.proxies:
            return None

        with self.proxy_lock:
            exclude = exclude or set()
            now = time.time()
            available = [p for p in self.proxies
                        if p not in self.failed_proxies 
                        and p not in exclude
                        and self.proxy_cooldowns.get(p, 0) < now]

            if not available:
                # If everything is on cooldown, we must wait or reset
                remaining_cooldowns = [self.proxy_cooldowns.get(p, 0) - now for p in self.proxies if p not in self.failed_proxies]
                if remaining_cooldowns:
                    # print(f"  (All {len(self.proxies)} proxies are on cooldown... Fastest in {min(remaining_cooldowns):.1f}s)")
                    pass
                else:
                    self.failed_proxies.clear()
                    available = [p for p in self.proxies if p not in exclude]

            if not available:
                return None
            return random.choice(available)

    def mark_proxy_cooldown(self, proxy: str, duration: int = None):
        """Put a proxy on cooldown (thread-safe)"""
        duration = duration or RATE_LIMIT_BACKOFF
        with self.proxy_lock:
            self.proxy_cooldowns[proxy] = time.time() + duration

    def mark_proxy_failed(self, proxy: str):
        """Mark a proxy as failed (thread-safe)"""
        with self.proxy_lock:
            self.failed_proxies.add(proxy)

    def refresh_token(self):
        """Automated token refresh using refresh_token endpoint with dynamic signing"""
        print("\n[!] Token expired, attempting automated refresh...")
        refresh_url = "https://auth.onskin.com/api/auth/v0.2/token"
        
        # dynamic signature generation
        timestamp = int(time.time())
        data_to_sign = f"{timestamp}:{REFRESH_TOKEN}:{REFRESH_KEY_ID}:{SIGN_SALT}"
        sign = hmac.new(bytes.fromhex(SIGN_KEY_HEX), data_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()

        refresh_headers = {
            'Host': 'auth.onskin.com',
            'Connection': 'keep-alive',
            'Accept': '*/*',
            'User-Agent': HEADERS['User-Agent'],
            'Accept-Language': HEADERS['Accept-Language'],
            'Content-Type': 'application/json'
        }
        payload = {
            "sign": sign,
            "refresh_token": REFRESH_TOKEN,
            "key_id": REFRESH_KEY_ID,
            "timestamp": timestamp
        }
        
        try:
            response = requests_cffi.patch(refresh_url, headers=refresh_headers, json=payload, impersonate="safari172_ios", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                new_access_token = data.get('data', {}).get('access_token')
                if new_access_token:
                    self.update_access_token_state(new_access_token)
                    print("✓ Token successfully refreshed automatically!\n")
                    return True
            
            print(f"✗ Auto-refresh failed (HTTP {response.status_code}).")
            print(f"  Response: {response.text}")
            return False
        except Exception as e:
            print(f"✗ Error during refresh: {e}")
            return False
        except Exception as e:
            print(f"✗ Error during refresh: {e}")
            return False

    def update_access_token_state(self, new_token: str):
        """Update access token in memory, headers and file"""
        with self.token_lock:
            self.bearer_token = new_token
            HEADERS['Authorization'] = f"Bearer {new_token}"
            self.token_expired = False
            # Update the token in the script file for persistence
            self.update_token_in_file(new_token)

    def update_refresh_config_in_file(self, new_sign: str, new_ts: int):
        """Update REFRESH_SIGN and REFRESH_TIMESTAMP in the script file"""
        global REFRESH_SIGN, REFRESH_TIMESTAMP
        REFRESH_SIGN = new_sign
        REFRESH_TIMESTAMP = new_ts
        try:
            with open(__file__, 'r', encoding='utf-8') as f:
                content = f.read()
            import re
            content = re.sub(r'REFRESH_SIGN = "[^"]+"', f'REFRESH_SIGN = "{new_sign}"', content)
            content = re.sub(r'REFRESH_TIMESTAMP = \d+', f'REFRESH_TIMESTAMP = {new_ts}', content)
            with open(__file__, 'w', encoding='utf-8') as f:
                f.write(content)
        except Exception as e:
            print(f"⚠ Could not update refresh config in file: {e}")

    def update_token_in_file(self, new_token: str):
        """Update bearer token in this file for next run"""
        try:
            with open(__file__, 'r', encoding='utf-8') as f:
                content = f.read()
            # Find and replace the token line
            import re
            new_content = re.sub(r'BEARER_TOKEN = "[^"]+"', f'BEARER_TOKEN = "{new_token}"', content)
            with open(__file__, 'w', encoding='utf-8') as f:
                f.write(new_content)
        except Exception as e:
            print(f"⚠ Could not update file: {e}")

    def check_token_expired(self, response: requests_cffi.Response) -> bool:
        """Check if response indicates token expiry"""
        if response.status_code == 401:
            try:
                data = response.json()
                if data.get('status') == 4099 or 'expired' in data.get('detail', '').lower():
                    return True
            except:
                pass
        return False

    def load_progress(self):
        """Load previously fetched barcodes from JSONL file"""
        try:
            with open(EXISTING_RESULTS_FILE, 'r', encoding='utf-8') as f:
                for line in f:
                    try:
                        data = json.loads(line.strip())
                        if 'scanned_barcode' in data:
                            self.processed_barcodes.add(data['scanned_barcode'])
                    except:
                        continue
                print(f"✓ Loaded {len(self.processed_barcodes)} previously fetched barcodes")
        except FileNotFoundError:
            pass

    def save_result(self, result: Dict):
        """Append single result to JSONL file (thread-safe)"""
        with self.file_lock:
            try:
                with open(OUTPUT_FILE, 'a', encoding='utf-8') as f:
                    f.write(json.dumps(result, ensure_ascii=False) + '\n')
            except Exception as e:
                print(f"Error saving result: {e}")

    def fetch_by_barcode(self, barcode: str, session: requests_cffi.Session) -> Optional[Dict]:
        """Fetch product by barcode with RateLimitError support"""
        max_retries = 2
        for retry in range(max_retries):
            try:
                url = f"{BASE_URL}/barcodes/EAN-13/{barcode}?priority=0"
                response = session.get(url, timeout=5)

                if response.status_code in [429, 403]:
                    raise RateLimitError(f"{response.status_code} for barcode {barcode}")

                if self.check_token_expired(response):
                    if self.refresh_token():
                        session.headers.update(HEADERS)
                        response = session.get(url, timeout=5)
                    else:
                        print("🔴 Automated refresh failed.")
                        return None

                if response.status_code == 200:
                    data = response.json()
                    if data and 'data' in data and isinstance(data['data'], dict):
                        return data['data']
                return None

            except RateLimitError:
                raise
            except Exception:
                if retry < max_retries - 1:
                    time.sleep(1)
                    continue
        return None

    def fetch_product_detail(self, product_id: int, session: requests_cffi.Session) -> Optional[Dict]:
        """Fetch detailed product information with RateLimitError support"""
        max_retries = 2
        for retry in range(max_retries):
            try:
                url = f"{BASE_URL}/products/{product_id}"
                response = session.get(url, timeout=5)

                if response.status_code in [429, 403]:
                    raise RateLimitError(f"{response.status_code} for product {product_id}")
                
                if self.check_token_expired(response):
                    if self.refresh_token():
                        session.headers.update(HEADERS)
                        response = session.get(url, timeout=5)
                    else:
                        return None

                if response.status_code == 200:
                    return response.json()
                return None

            except RateLimitError:
                raise
            except Exception:
                if retry < max_retries - 1:
                    time.sleep(1)
                    continue
        return None

    def process_product(self, product: Dict, session: requests_cffi.Session) -> Optional[Dict]:
        """Process a single product (thread-safe)"""
        barcode = str(product.get('barcode', '')).strip()
        if barcode:
            if len(barcode) > 13:
                barcode = barcode[-13:]
            elif len(barcode) < 13:
                barcode = barcode.zfill(13)
        
        name = product.get('name', '')

        with self.processed_lock:
            if barcode in self.processed_barcodes:
                with self.stats_lock:
                    self.stats['skipped'] += 1
                return None

        with self.stats_lock:
            self.stats['started'] += 1
            current_num = self.stats['started']

        print(f"[{current_num}] Processing: {name[:50]}... ({barcode})")

        result = {
            'scanned_barcode': barcode,
            'source_data': product,
            'barcode_api_response': None,
            'product_details': None
        }

        barcode_response = self.fetch_by_barcode(barcode, session)
        result['barcode_api_response'] = barcode_response

        if barcode_response:
            product_data = barcode_response.get('product')
            if product_data and isinstance(product_data, dict):
                product_id = product_data.get('product_id')
                if product_id:
                    detail = self.fetch_product_detail(product_id, session)
                    if detail:
                        result['product_details'] = detail
                        with self.stats_lock:
                            self.stats['found_by_barcode'] += 1
                        return result

        if not result['barcode_api_response']:
            with self.stats_lock:
                self.stats['not_found'] += 1
        return result

    def _process_product_wrapper(self, product: Dict) -> Optional[Dict]:
        """Wrapper for parallel processing with proxy switching on 429"""
        max_attempts = 5
        tried_proxies = set()

        for attempt in range(max_attempts):
            if self.token_expired:
                return None

            session = requests_cffi.Session(impersonate="safari172_ios")
            session.headers.update(HEADERS)
            current_proxy = None

            if self.proxies:
                current_proxy = self.get_random_proxy(exclude=tried_proxies)
                if current_proxy:
                    session.proxies = {'http': f'http://{current_proxy}', 'https': f'http://{current_proxy}'}
                    tried_proxies.add(current_proxy)

            try:
                result = self.process_product(product, session)
                if result:
                    self.save_result(result)
                    with self.processed_lock:
                        self.processed_barcodes.add(result['scanned_barcode'])
                    with self.stats_lock:
                        self.stats['total'] += 1
                return result

            except RateLimitError as e:
                if current_proxy:
                    print(f"  ⚠ Rate Limit on {current_proxy}. Cooldown {RATE_LIMIT_BACKOFF}s. Switching...")
                    self.mark_proxy_cooldown(current_proxy)
                else:
                    backoff = RATE_LIMIT_BACKOFF + (attempt * 60)
                    print(f"  ⚠ Rate Limit ({e}) on main IP. Waiting {backoff}s...")
                    time.sleep(backoff)
                continue

            except requests_cffi.errors.RequestsError:
                if current_proxy:
                    self.mark_proxy_failed(current_proxy)
                continue

            except Exception as e:
                print(f"  ✗ Error: {e}")
                with self.stats_lock:
                    self.stats['errors'] += 1
                return None
            finally:
                time.sleep(REQUEST_DELAY * (0.5 + random.random()))

    def run(self):
        print(f"Starting OnSkin Fetcher with {self.num_workers} workers...")
        if not self.proxies and self.num_workers > 2:
             print("⚠ WARNING: Using many workers on a single IP without proxies will likely lead to a 429.")
             print("Consider reducing --workers to 1 or 2.")
        
        self.load_progress()
        
        try:
            with open(INPUT_FILE, 'r', encoding='utf-8') as f:
                products = json.load(f)
        except Exception as e:
            print(f"Error loading {INPUT_FILE}: {e}")
            return

        to_process = [p for p in products if str(p.get('barcode', '')).strip().zfill(13) not in self.processed_barcodes]
        print(f"{len(to_process)} products to process. ({len(self.processed_barcodes)} already done)")

        if not to_process:
            return

        try:
            with ThreadPoolExecutor(max_workers=self.num_workers) as executor:
                futures = {executor.submit(self._process_product_wrapper, p): p for p in to_process}
                for i, future in enumerate(as_completed(futures)):
                    if (i+1) % 50 == 0:
                        self.print_stats()
        except KeyboardInterrupt:
            print("\nStopped by user.")
        finally:
            self.print_stats()

    def print_stats(self):
        with self.stats_lock:
            print(f"\n--- Stats: Total {self.stats['total']}, Found {self.stats['found_by_barcode']}, Not Found {self.stats['not_found']}, Errors {self.stats['errors']} ---")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--workers', type=int, default=1)
    parser.add_argument('--proxies', type=str, default=None)
    args = parser.parse_args()
    OnSkinFetcher(num_workers=args.workers, proxy_file=args.proxies).run()
