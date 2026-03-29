import pandas as pd
import json
import os
import re

def parse_ingredients(ingredients_str):
    if pd.isna(ingredients_str) or not isinstance(ingredients_str, str):
        return []
    # Remove leading colons or 'INGREDIENTS:' text if any
    ingredients_str = re.sub(r'^(?:INGREDIENTS:\s*|AND/UND INGREDIENTS:\s*|AND INGREDIENTS:\s*|:\s*)', '', ingredients_str, flags=re.IGNORECASE)
    # Split by comma
    ingredients = [i.strip() for i in ingredients_str.split(',')]
    return [i for i in ingredients if i]

def process_file(filepath, brand_name, image_cols, ingredient_col):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return []
        
    df = pd.read_csv(filepath)
    results = []
    for _, row in df.iterrows():
        # Get name
        name = row['name'] if 'name' in row and pd.notna(row['name']) else ''
        if not name and 'title' in row and pd.notna(row['title']):
            name = row['title']
        
        name = str(name).strip()
        if not name:
            continue
            
        # Get images
        images = []
        for col in image_cols:
            if col in row and pd.notna(row[col]):
                img_url = str(row[col]).strip()
                if img_url:
                    images.append(img_url)
                    
        # Get ingredients
        ingredients_str = row[ingredient_col] if ingredient_col in row else ''
        ingredients = parse_ingredients(ingredients_str)
        
        # Build product
        product = {
            "barcode": "", # Not available in EWG data
            "name": name,
            "brand": brand_name,
            "description": "", # Not clearly available in EWG data
            "product_ingredients": ingredients,
            "image_urls": images
        }
        
        # Add description if we can infer one, otherwise skip
        # For EWG, there isn't a clear description field in these dumps,
        # but we can look for other fields if needed.
        
        results.append(product)
        
    return results

def main():
    base_dir = "/Users/aleyna/Desktop/embedding"
    
    essence_file = os.path.join(base_dir, "ewg-org-essence-2026-03-14.csv")
    loreal_file = os.path.join(base_dir, "ewg-org-loreal-2026-03-14-2.csv")
    maybelline_file = os.path.join(base_dir, "ewg-org-maybelline.csv")
    
    all_products = []
    
    # 1. Essence
    all_products.extend(
        process_file(
            essence_file, 
            "Essence", 
            image_cols=['image', 'image_1'], 
            ingredient_col='Ingredients'
        )
    )
    
    # 2. Loreal
    all_products.extend(
        process_file(
            loreal_file, 
            "Loreal Paris", 
            image_cols=['image', 'image_1'], 
            ingredient_col='ingredients_from_packaging'
        )
    )
    
    # 3. Maybelline
    all_products.extend(
        process_file(
            maybelline_file, 
            "Maybelline New York", 
            image_cols=['image', 'image2', 'image_1'], 
            ingredient_col='ingredients'
        )
    )
    
    out_file = os.path.join(base_dir, "ewg_products_combined.json")
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(all_products, f, ensure_ascii=False, indent=4)
        
    print(f"Processed {len(all_products)} products.")
    print(f"Saved to {out_file}")

if __name__ == "__main__":
    main()
