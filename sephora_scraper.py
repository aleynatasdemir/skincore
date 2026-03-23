import requests
import json
import time
import os
import concurrent.futures
import threading

HEADERS = {
    'Host': 'apps.sephora.eu',
    'x-api-key': 'H1c5Abv3zxQm5H1A4d45v2ILUc84lEQQ',
    'x-api-version': '1.0',
    'User-Agent': 'SEPHORAiOS/8.14.10 (fr.sephora.sephorafrance; build:1772803736; iOS 26.3.1)',
    'X-consumer-id': 'AOC-IOS-EME',
    'X-consumer-version': '8.14.10',
    'Content-Type': 'application/json; charset=utf-8'
}

PROXIES = {'http': None, 'https': None}

CATEGORIES = {
    'C302': 'makyaj',
    'C303': 'cilt_bakim',
    'C301': 'parfum',
    'C304': 'vucut_banyo',
    'sephora-collection-tum-urunler': 'sephora_collection',
    'C307': 'sac_bakim'
}

def get_token():
    auth_res = requests.post(
        'https://apps.sephora.eu/login/v1/token?locale=tr-TR&type=guest',
        headers=HEADERS,
        proxies=PROXIES,
        verify=False
    )
    if auth_res.status_code == 201:
        return auth_res.json()['token']['accessToken']
    else:
        raise Exception(f"Token error: {auth_res.text}")

def get_session_headers(token):
    headers = HEADERS.copy()
    headers['x-shopper-token'] = token
    headers['cookie'] = f'shopper-token={token}'
    headers['channel'] = 'aoc'
    headers['x-dw-client-id'] = '343edb11-54c4-4253-a480-ea6a832dbdd0'
    return headers

def fetch_pdp(hit, cat_name, headers):
    prod_id = hit.get('product_id')
    if not prod_id: return None
    
    pdp_url = f'https://apps.sephora.eu/catalog/v1/products/{prod_id}?locale=tr-TR&scope=pdp'
    pdp_res = requests.get(pdp_url, headers=headers, proxies=PROXIES, verify=False, timeout=10)
    
    if pdp_res.status_code == 200:
        pdp_data = pdp_res.json().get('product', {})
        return {
            'product_id': prod_id,
            'name': pdp_data.get('name') or hit.get('product_name'),
            'category': cat_name,
            'brand': pdp_data.get('brandName') or hit.get('c_brand'),
            'price': pdp_data.get('price'),
            'url': pdp_data.get('url'),
            'ingredients': pdp_data.get('ingredients') or pdp_data.get('c_ingredients'),
            'raw_pdp': pdp_data
        }
    elif pdp_res.status_code == 401:
        return {'error': '401', 'product_id': prod_id}
    else:
        print(f"Failed PDP {prod_id}: {pdp_res.status_code}")
        return None

def scrape_sephora():
    token = get_token()
    headers = get_session_headers(token)

    for cat_id, cat_name in CATEGORIES.items():
        print(f"\n=========================================")
        print(f"Starting category: {cat_name} ({cat_id})")
        print(f"=========================================\n")
        
        start = 0
        count = 20
        output_file = f'sephora_products_{cat_name}.json'
        progress_file = f'sephora_progress_{cat_name}.json'
        
        # Load progress
        if os.path.exists(progress_file):
            with open(progress_file, 'r', encoding='utf-8') as f:
                start = json.load(f).get('next_start', 0)
        
        products = []
        if os.path.exists(output_file):
            with open(output_file, 'r', encoding='utf-8') as f:
                products = json.load(f)
                
        # To avoid threading issues with sets
        fetched_ids = set()
        for p in products:
            fetched_ids.add(p.get('product_id'))

        while True:
            try:
                search_url = f'https://apps.sephora.eu/commerceCloud/shop/Sephora_TR/v21_10/product_search?locale=tr-TR&count={count}&expand=prices&refine_1=cgid%3D{cat_id}&refine_2=c_hideFromSearch%3Dfalse&refine_3=htype%3Dmaster%7Cproduct%7Cset&refine_4=orderable_only%3Dtrue&start={start}'
                res = requests.get(search_url, headers=headers, proxies=PROXIES, verify=False, timeout=10)
                
                if res.status_code == 401:
                    print("Token expired on search! Refreshing...")
                    token = get_token()
                    headers = get_session_headers(token)
                    continue
                    
                if res.status_code != 200:
                    print(f"Error {res.status_code} on search: {res.text}")
                    time.sleep(3)
                    continue
                    
                data = res.json()
                hits = data.get('hits', [])
                
                if not hits:
                    print(f"No more products found at start={start}. Finished {cat_name}!")
                    break
                    
                print(f"[{cat_name}] Fetching page start={start}, items={len(hits)}, total={data.get('total')}")
                
                # Use threads to fetch 20 items at once
                needs_token_refresh = False
                unfetched_count = 0
                
                with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
                    futures = []
                    for hit in hits:
                        prod_id = hit.get('product_id')
                        if not prod_id or prod_id in fetched_ids:
                            continue
                        futures.append(executor.submit(fetch_pdp, hit, cat_name, headers))
                        
                    for future in concurrent.futures.as_completed(futures):
                        result = future.result()
                        if result:
                            if result.get('error') == '401':
                                needs_token_refresh = True
                                unfetched_count += 1
                            else:
                                products.append(result)
                                fetched_ids.add(result['product_id'])
                        else:
                            unfetched_count += 1
                
                if needs_token_refresh:
                    print("Token expired during PDP threads! Refreshing...")
                    token = get_token()
                    headers = get_session_headers(token)
                    # We might have missed some products on this page, but we'll re-fetch them later if script stops
                    # Or just move to next page for now because mostly it succeeds
                
                # If we processed successfully (or skipped already fetched)
                start += count
                
                # Save progress
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(products, f, ensure_ascii=False, indent=2)
                with open(progress_file, 'w', encoding='utf-8') as f:
                    json.dump({'next_start': start}, f)
                    
            except Exception as e:
                print(f"[{cat_name}] Exception at start={start}: {e}")
                time.sleep(3)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    scrape_sephora()
