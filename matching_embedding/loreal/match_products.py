import json
import os
import numpy as np
import faiss
from rapidfuzz import fuzz

EWG_EMBED = "embedded_loreal_ewg_products.json"
EWG_RAW = "loreal_ewg_products.json"
LOCAL_DATA = "embedded_loreal_local_products.json"
BARCODE_DATA = "loreal_products.json"
OUTPUT_FILE = "matched_loreal_products.json"

TOP_K = 5
TEXT_THRESHOLD = 60


print("Loading datasets...")

with open(EWG_EMBED, "r", encoding="utf-8") as f:
    ewg_embed = json.load(f)

with open(EWG_RAW, "r", encoding="utf-8") as f:
    ewg_raw = json.load(f)

with open(LOCAL_DATA, "r", encoding="utf-8") as f:
    local = json.load(f)

print("EWG EMBED:", len(ewg_embed))
print("EWG RAW:", len(ewg_raw))
print("LOCAL:", len(local))


# -----------------------------
# BARCODE MAP
# -----------------------------

barcode_map = {}

try:
    with open(BARCODE_DATA, "r", encoding="utf-8") as f:
        raw = json.load(f)

    for item in raw:
        name = item.get("name")
        barcode = item.get("barcode")

        if name and barcode:
            barcode_map[name.strip()] = str(barcode).strip()

except:
    print("Barcode file not found")


# -----------------------------
# NORMALIZE
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

    if not text:
        return ""

    text = text.lower()

    for tr, en in translation.items():
        text = text.replace(tr, en)

    return text


# -----------------------------
# EXTRACT TEXT
# -----------------------------

def get_product_info(item):

    text = ""
    image = None

    for part in item.get("content", []):
        if "text" in part and not text:
            text = part["text"].strip()
        if "image" in part and image is None:
            image = part["image"]

    return text, image


ewg_raw_image_by_text = {}
ewg_raw_image_by_norm = {}
ewg_raw_norm_entries = []

for item in ewg_raw:
    raw_text, raw_image = get_product_info(item)
    if not raw_text or not raw_image:
        continue

    if raw_text not in ewg_raw_image_by_text:
        ewg_raw_image_by_text[raw_text] = raw_image

    raw_norm = normalize(raw_text)
    if raw_norm and raw_norm not in ewg_raw_image_by_norm:
        ewg_raw_image_by_norm[raw_norm] = raw_image

    if raw_norm:
        ewg_raw_norm_entries.append((raw_norm, raw_image))


def resolve_ewg_image(best_text, best_image):

    if best_image:
        return best_image

    image = ewg_raw_image_by_text.get(best_text)
    if image:
        return image

    best_norm = normalize(best_text)
    if not best_norm:
        return None

    image = ewg_raw_image_by_norm.get(best_norm)
    if image:
        return image

    fuzzy_best_score = -1
    fuzzy_best_image = None

    for raw_norm, raw_image in ewg_raw_norm_entries:
        score = fuzz.token_set_ratio(best_norm, raw_norm)
        if score > fuzzy_best_score:
            fuzzy_best_score = score
            fuzzy_best_image = raw_image

    if fuzzy_best_score >= 80:
        return fuzzy_best_image

    return None


# -----------------------------
# FILTER EMBEDDINGS
# -----------------------------

ewg_embed = [x for x in ewg_embed if "embedding" in x]
local = [x for x in local if "embedding" in x]


# -----------------------------
# EMBEDDING MATRICES
# -----------------------------

ewg_vectors = np.array([x["embedding"] for x in ewg_embed]).astype("float32")
local_vectors = np.array([x["embedding"] for x in local]).astype("float32")

dimension = ewg_vectors.shape[1]

faiss.normalize_L2(ewg_vectors)
faiss.normalize_L2(local_vectors)


# -----------------------------
# FAISS INDEX
# -----------------------------

index = faiss.IndexFlatIP(dimension)
index.add(ewg_vectors)

print("FAISS index ready")


# -----------------------------
# SEARCH
# -----------------------------

distances, indices = index.search(local_vectors, TOP_K)

matches = []

print("Matching...")


for i in range(len(local)):

    local_text, local_image = get_product_info(local[i])

    local_norm = normalize(local_text)

    if not local_norm:
        continue

    best_score = 0
    best_text = None
    best_image = None

    for j in range(TOP_K):

        idx = indices[i][j]

        if idx < 0 or idx >= len(ewg_embed):
            continue

        ewg_text, ewg_image = get_product_info(ewg_embed[idx])
        ewg_norm = normalize(ewg_text)

        score = fuzz.partial_ratio(local_norm, ewg_norm)

        if score > best_score:
            best_score = score
            best_text = ewg_text
            best_image = ewg_image


    if best_score < TEXT_THRESHOLD or not best_text:
        continue

    ewg_image = resolve_ewg_image(best_text, best_image)


    barcode = barcode_map.get(local_text)

    if not barcode and local_image:
        barcode = os.path.splitext(os.path.basename(local_image))[0]


    matches.append({
        "barcode": barcode,
        "local_product": local_text,
        "local_image": local_image,
        "ewg_product": best_text,
        "ewg_image": ewg_image,
        "text_score": best_score
    })


# -----------------------------
# SORT
# -----------------------------

matches = sorted(matches, key=lambda x: x["text_score"], reverse=True)

print("\nTotal matches:", len(matches))

for m in matches[:10]:
    print(m["text_score"], "|", m["local_product"], "->", m["ewg_product"])


# -----------------------------
# SAVE
# -----------------------------

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(matches, f, indent=2, ensure_ascii=False)

print("\nSaved:", OUTPUT_FILE)