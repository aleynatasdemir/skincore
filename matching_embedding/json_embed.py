import json

# ----------------
# FILE PATHS
# ----------------

INPUT_FILE = "loreal_products.json"
OUTPUT_FILE = "loreal_local_products.json"

# ----------------
# LOAD DATA
# ----------------

with open(INPUT_FILE, "r", encoding="utf-8") as f:
    products = json.load(f)

new_data = []

# ----------------
# CONVERT FORMAT
# ----------------

for item in products:

    barcode = item.get("barcode")
    name = item.get("name")

    if not barcode or not name:
        continue

    new_item = {
        "content": [
            {
                "text": name
            },
            {
                "image": f"loreal_local_img/{barcode}.jpg"
            }
        ]
    }

    new_data.append(new_item)

# ----------------
# SAVE FILE
# ----------------

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(new_data, f, ensure_ascii=False, indent=2)

print("Bitti")
print("Toplam ürün:", len(new_data))