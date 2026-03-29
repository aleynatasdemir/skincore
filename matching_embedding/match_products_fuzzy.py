import json
import os
import numpy as np
import faiss
from rapidfuzz import fuzz

EWG_DATA = "embedded_loreal_ewg_products.json"
WATS_DATA = "embedded_loreal_local_products.json"
OUTPUT_FILE = "matched_loreal_products.json"

# -----------------------------
# DATA LOAD
# -----------------------------

print("Datasetler yükleniyor...")

with open(EWG_DATA, "r", encoding="utf-8") as f:
    ewg = json.load(f)

with open(WATS_DATA, "r", encoding="utf-8") as f:
    local = json.load(f)

print("EWG:", len(ewg))
print("LOCAL (Watsons):", len(local))

# -----------------------------
# BARCODE LOOKUP
# -----------------------------
print("loreal_products.json'dan barkodlar yükleniyor...")
barcode_map = {}
try:
    with open("loreal_products.json", "r", encoding="utf-8") as f:
        loreal_raw = json.load(f)
        for item in loreal_raw:
            name = item.get("name")
            barcode = item.get("barcode")
            if name and barcode:
                barcode_map[name.strip()] = str(barcode).strip()
    print(f"Toplam {len(barcode_map)} tekil barkod haritalandı.")
except Exception as e:
    print(f"Uyarı: loreal_products.json okunamadı ({e}).")

# -----------------------------
# TEXT NORMALIZATION
# -----------------------------

translation = {
    "fondöten": "foundation",
    "pudra": "powder",
    "kapatıcı": "concealer",
    "allık": "blush",
    "aydınlatıcı": "highlighter",
    "far": "eyeshadow",
    "göz kalemi": "eyeliner",
    "maskara": "mascara",
    "rimel": "mascara",
    "ruj": "lipstick",
    "oje": "nail polish"
}

def normalize(text):
    if text is None:
        return ""
    text = text.lower()
    for tr, en in translation.items():
        text = text.replace(tr, en)
    return text

# -----------------------------
# TEXT + IMAGE EXTRACT
# -----------------------------

def get_product_info(item):
    text = None
    image = None
    
    for part in item["content"]:
        if "text" in part:
            text = part["text"]
        if "image" in part:
            image = part["image"]
            
    return text, image

# Filter out elements without embeddings
ewg = [x for x in ewg if "embedding" in x]
local = [x for x in local if "embedding" in x][:20] # Sadece 20 ürünü alıyoruz (Göstermelik)

if not ewg or not local:
    print("HATA: Embedding bulunamadı! Lütfen generate_embeddings.py'yi iki veri seti için de çalıştırın.")
    exit(1)

# -----------------------------
# EMBEDDING MATRICES
# -----------------------------

ewg_vectors = np.array([x["embedding"] for x in ewg]).astype("float32")
local_vectors = np.array([x["embedding"] for x in local]).astype("float32")

dimension = ewg_vectors.shape[1]

print("Embedding dimension:", dimension)

faiss.normalize_L2(ewg_vectors)
faiss.normalize_L2(local_vectors)

# -----------------------------
# FAISS INDEX
# -----------------------------

index = faiss.IndexFlatIP(dimension)
index.add(ewg_vectors)

# -----------------------------
# SEARCH (TOP 5)
# -----------------------------

distances, indices = index.search(local_vectors, 5)

matches = []

print("Eşleşmeler hesaplanıyor...")

for i in range(len(local)):
    local_text, local_image = get_product_info(local[i])
    local_norm = normalize(local_text)

    best_score = 0
    best_match_idx = None
    best_image = None
    best_text = None

    for j in range(5):
        idx = indices[i][j]
        
        # Sınır kontrolü (her ihtimale karşı)
        if idx < 0 or int(idx) >= len(ewg):
            continue

        ewg_text, ewg_image = get_product_info(ewg[int(idx)])
        ewg_norm = normalize(ewg_text)

        text_score = fuzz.token_set_ratio(str(local_norm), str(ewg_norm))

        if text_score > best_score:
            best_score = text_score
            best_match_idx = idx
            best_image = ewg_image
            best_text = ewg_text

    barcode = barcode_map.get(local_text)
    if not barcode and local_image:
        barcode = os.path.splitext(os.path.basename(local_image))[0]

    matches.append({
        "barcode": barcode,
        "local_product": local_text,
        "local_image": local_image,
        "ewg_product": best_text,
        "ewg_image": best_image,
        "text_score": best_score
    })

# -----------------------------
# SORT RESULTS
# -----------------------------

matches = sorted(matches, key=lambda x: x["text_score"], reverse=True)

print(f"\nToplam {len(matches)} eşleşme bulundu.")
print("\nEşleşmeler:\n")

for m in matches[:20]:
    print(f"{m['text_score']} | {m['local_product']} -> {m['ewg_product']}")

# -----------------------------
# SAVE RESULTS
# -----------------------------

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(matches, f, indent=2, ensure_ascii=False)

print("\nEşleşmeler kaydedildi:", OUTPUT_FILE)