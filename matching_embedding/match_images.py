import json
import numpy as np

# ----------------
# FILES
# ----------------

LOCAL_FILE = "embedded_loreal_local_products.json"
EWG_FILE = "embedded_loreal_ewg_products.json"

OUTPUT_FILE = "matched_products.json"

SIMILARITY_THRESHOLD = 0.85

# ----------------
# LOAD DATA
# ----------------

with open(LOCAL_FILE, "r", encoding="utf-8") as f:
    local_products = json.load(f)

with open(EWG_FILE, "r", encoding="utf-8") as f:
    ewg_products = json.load(f)

print("Local ürün:", len(local_products))
print("EWG ürün:", len(ewg_products))

# ----------------
# COSINE SIMILARITY
# ----------------

def cosine_similarity(a, b):

    a = np.array(a)
    b = np.array(b)

    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

# ----------------
# MATCHING
# ----------------

matches = []

for i, local in enumerate(local_products):

    local_embedding = local.get("embedding")

    if not local_embedding:
        continue

    best_score = -1
    best_match = None

    for ewg in ewg_products:

        ewg_embedding = ewg.get("embedding")

        if not ewg_embedding:
            continue

        score = cosine_similarity(local_embedding, ewg_embedding)

        if score > best_score:
            best_score = score
            best_match = ewg

    if best_score >= SIMILARITY_THRESHOLD:

        matches.append({
            "local_product": local,
            "ewg_product": best_match,
            "similarity": float(best_score)
        })

    if i % 20 == 0:
        print(f"{i}/{len(local_products)} işlendi")

# ----------------
# SAVE
# ----------------

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(matches, f, ensure_ascii=False, indent=2)

print("\nBitti")
print("Match sayısı:", len(matches))