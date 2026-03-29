import json
import os

matched_files = [
    '/Users/aleyna/Desktop/embedding/matched_loreal_products.json',
    '/Users/aleyna/Desktop/embedding/matched_products_essence.json',
    '/Users/aleyna/Desktop/embedding/matched_products.json'
]

ewg_file = '/Users/aleyna/Desktop/embedding/ewg_products_combined.json'

matched_names_exact = set()
matched_names_prefix = []

for file in matched_files:
    if os.path.exists(file):
        with open(file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            for item in data:
                ewg_name = item.get('ewg_product')
                if ewg_name:
                    if ewg_name.endswith('...'):
                        matched_names_prefix.append(ewg_name[:-3])
                    else:
                        matched_names_exact.add(ewg_name)

print(f"Loaded {len(matched_names_exact)} exact matches and {len(matched_names_prefix)} prefix matches.")

with open(ewg_file, 'r', encoding='utf-8') as f:
    ewg_data = json.load(f)

print(f"Original EWG products count: {len(ewg_data)}")

filtered_ewg_data = []
for product in ewg_data:
    name = product.get('name')
    if not name:
        continue
        
    is_matched = False
    if name in matched_names_exact:
        is_matched = True
    else:
        for prefix in matched_names_prefix:
            if name.startswith(prefix):
                is_matched = True
                break
                
    if not is_matched:
        filtered_ewg_data.append(product)

print(f"Filtered EWG products count: {len(filtered_ewg_data)}")
print(f"Removed: {len(ewg_data) - len(filtered_ewg_data)} products")

with open(ewg_file, 'w', encoding='utf-8') as f:
    json.dump(filtered_ewg_data, f, indent=4, ensure_ascii=False)

print("Saved filtered data.")
