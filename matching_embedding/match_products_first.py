import json
import numpy as np
import faiss

DATA_FILE = "embedded_products.json"
OUTPUT_FILE = "matched_products.json"

THRESHOLD = 0.75

print("Dataset yükleniyor...")

with open(DATA_FILE, "r", encoding="utf-8") as f:
    data = json.load(f)

print("Toplam ürün:", len(data))


# ---------------------------------------------------
# TEXT VE IMAGE PATH ÇIKARMA
# ---------------------------------------------------

def get_product_info(item):

    text = None
    image = None

    for part in item.get("content", []):

        if "text" in part:
            text = part["text"]

        if "image" in part:
            image = part["image"]

    return text, image


# ---------------------------------------------------
# EWG / LOCAL SPLIT
# ---------------------------------------------------

last_web_scraper = -1

for i, item in enumerate(data):

    for part in item.get("content", []):
        if "image" in part and "web_scraper" in part["image"]:
            last_web_scraper = i

split_index = last_web_scraper + 1

ewg = data[:split_index]
local = data[split_index:]

print("EWG ürün:", len(ewg))
print("LOCAL ürün:", len(local))


# ---------------------------------------------------
# EMBEDDING MATRİSİ
# ---------------------------------------------------

ewg_vectors = np.array([x["embedding"] for x in ewg]).astype("float32")
local_vectors = np.array([x["embedding"] for x in local]).astype("float32")

dimension = ewg_vectors.shape[1]

print("Embedding dimension:", dimension)

faiss.normalize_L2(ewg_vectors)
faiss.normalize_L2(local_vectors)


# ---------------------------------------------------
# FAISS INDEX
# ---------------------------------------------------

index = faiss.IndexFlatIP(dimension)
index.add(ewg_vectors)


# ---------------------------------------------------
# SEARCH
# ---------------------------------------------------

print("Eşleşmeler aranıyor...")

distances, indices = index.search(local_vectors, 1)

matches = []

for i in range(len(local)):

    score = float(distances[i][0])
    idx = indices[i][0]

    if score >= THRESHOLD:

        local_text, local_image = get_product_info(local[i])
        ewg_text, ewg_image = get_product_info(ewg[idx])

        matches.append({
            "local_product": local_text,
            "local_image": local_image,
            "ewg_product": ewg_text,
            "ewg_image": ewg_image,
            "score": score
        })


# ---------------------------------------------------
# SONUÇ SIRALA
# ---------------------------------------------------

matches = sorted(matches, key=lambda x: x["score"], reverse=True)

print("\nBulunan eşleşme:", len(matches))

print("\nTop 10 eşleşme:\n")

for m in matches[:10]:
    print(
        round(m["score"], 3),
        "|",
        m["local_product"],
        "->",
        m["ewg_product"]
    )


# ---------------------------------------------------
# DOSYAYA KAYDET
# ---------------------------------------------------

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(matches, f, ensure_ascii=False, indent=2)

print("\nEşleşmeler kaydedildi:", OUTPUT_FILE)