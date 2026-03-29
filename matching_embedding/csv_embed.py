import pandas as pd
import json
import os

CSV_FILE = '/Users/aleyna/Desktop/embedding/watsons-essence-com-tr-2026-03-14.csv'
IMG_DIR = '/Users/aleyna/Desktop/embedding/essence_wats_img'
OUTPUT_JSON = '/Users/aleyna/Desktop/embedding/essence_wats_products.json'

def main():
    print(f"Reading {CSV_FILE}...")
    try:
        df = pd.read_csv(CSV_FILE)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    # Create mapping from ID to exact image filename
    img_map = {}
    if os.path.exists(IMG_DIR):
        for f in os.listdir(IMG_DIR):
            if f.startswith('.'): continue # Skip hidden files
            name_without_ext = os.path.splitext(f)[0]
            img_map[name_without_ext] = f
    
    results = []
    seen_ids = set()
    seen_names = set()
    
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
                identifier = str(raw_id).strip()
            
        if not identifier or identifier in seen_ids:
            continue
            
        name = row.get('name')
        if pd.isna(name):
            continue
            
        name = str(name).strip()
        if not name or name in seen_names:
            continue
            
        seen_ids.add(identifier)
        seen_names.add(name)
        
        content = [
            {"text": name}
        ]
        
        # If we successfully downloaded the image for this ID, link it
        if identifier in img_map:
            img_filename = img_map[identifier]
            content.append({
                "image": f"essence_wats_img/{img_filename}"
            })
            
        results.append({
            "content": content
        })
        
    with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
        
    print(f"✅ Created {OUTPUT_JSON} with {len(results)} items.")

if __name__ == '__main__':
    main()
