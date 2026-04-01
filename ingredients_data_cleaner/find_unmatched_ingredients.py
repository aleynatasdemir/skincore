"""
find_unmatched_ingredients.py
------------------------------
products koleksiyonundaki tüm product_ingredients'ları çeker,
IngredientMatchingService.cs ile AYNI eşleştirme mantığını Python'da uygular:
  1. Exact match  (inci_name, name, aliases)
  2. Parantez alternatifleri  "Aqua (Water)" → "Aqua" | "Water"
  3. Kolon-split  "INGREDIENTS: Aqua" → "Aqua"
  4. Slash-split  "Aqua/Water/Eau" → her parça
  5. Asterisk trim  "Glycerin*" → "Glycerin"
  6. Fuzzy match  (thefuzz, eşik ≥ 70)

Eşleşmeyen benzersiz içerikleri unmatched_ingredients.json dosyasına yazar.
"""

import os
import re
import json
from collections import defaultdict
from typing import Optional, Dict, List

from dotenv import load_dotenv
from pymongo import MongoClient

# thefuzz (FuzzySharp Python karşılığı)
try:
    from thefuzz import process as fuzz_process
except ImportError:
    from fuzzywuzzy import process as fuzz_process

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "unmatched_ingredients.json")
FUZZY_THRESHOLD = 70

# ──────────────────────────────────────────────
# Normalize (C# NormalizeIngredientName + NumericPrefixRegex)
# ──────────────────────────────────────────────
_HASH_PREFIX_RE  = re.compile(r"^#\d+\s*(ingrediente:\s*)?", re.IGNORECASE)
_NUMERIC_PFXR_RE = re.compile(r"^\d{3,}\s+")

def normalize(raw: str) -> str:
    s = raw.strip()
    s = _HASH_PREFIX_RE.sub("", s)

    upper = s.upper()
    if upper.startswith("INGREDIENTS:"):
        s = s[len("INGREDIENTS:"):].lstrip()
    elif upper.startswith("INGREDIENTS") and len(s) > 11 and not s[11].isalpha():
        s = s[11:].lstrip(": ")

    s = s.rstrip(".,; ")
    s = s.strip('"')
    s = _NUMERIC_PFXR_RE.sub("", s)
    return s.strip()


# ──────────────────────────────────────────────
# Lookup tablosu oluşturma
# ──────────────────────────────────────────────
def build_lookup(ingredients_col):
    """inci_name, name ve aliases üzerinden lower-case lookup dict döner."""
    lookup: Dict[str, dict] = {}

    for doc in ingredients_col.find({}):
        for field in ("inci_name", "name"):
            val = doc.get(field, "")
            if val:
                lookup.setdefault(val.lower().strip(), doc)

        for alias in doc.get("aliases", []) or []:
            if alias:
                lookup.setdefault(alias.lower().strip(), doc)

    return lookup


def exact_match(key: str, lookup: dict) -> bool:
    return key.lower().strip() in lookup


# ──────────────────────────────────────────────
# Tek bir raw ingredient string'ini eşleştir
# ──────────────────────────────────────────────
def match_ingredient(raw: str, lookup: dict, searchable_keys: List[str]) -> Optional[dict]:
    """
    Eşleşme bulunursa None döner (eşleşti).
    Bulunamazsa {"original": raw, "normalized": cleaned} döner (eşleşmedi).
    """
    if not raw or not raw.strip():
        return None  # boş → atla

    cleaned  = normalize(raw)
    norm_lc  = cleaned.lower().strip()

    if not norm_lc:
        return None

    # 1. Exact
    if exact_match(norm_lc, lookup):
        return None

    # 2. Parantez alternatifleri
    paren_idx = norm_lc.find("(")
    if paren_idx > 0:
        before = norm_lc[:paren_idx].strip()
        if exact_match(before, lookup):
            return None
        close_idx = norm_lc.find(")", paren_idx)
        if close_idx > paren_idx + 1:
            inside = norm_lc[paren_idx + 1:close_idx].strip()
            if exact_match(inside, lookup):
                return None

    # 3. Kolon-split
    colon_idx = norm_lc.rfind(":")
    if 0 < colon_idx < len(norm_lc) - 1:
        after_colon = norm_lc[colon_idx + 1:].strip()
        if exact_match(after_colon, lookup):
            return None

    # 4. Slash-split
    if "/" in norm_lc:
        for part in norm_lc.split("/"):
            if exact_match(part.strip(), lookup):
                return None

    # 5. Asterisk trim
    if norm_lc.endswith("*"):
        if exact_match(norm_lc.rstrip("*"), lookup):
            return None

    # 6. Fuzzy match
    if searchable_keys:
        result = fuzz_process.extractOne(norm_lc, searchable_keys, score_cutoff=FUZZY_THRESHOLD)
        if result:
            return None  # fuzzy eşleşme bulundu

    # Hiçbir yöntemle eşleşmedi
    return {"original": raw, "normalized": cleaned}


# ──────────────────────────────────────────────
# Ana mantık
# ──────────────────────────────────────────────
def main():
    print("MongoDB'ye bağlanılıyor...")
    mongo_client = MongoClient(MONGO_URI)
    db = mongo_client["kozmetik"]
    products_col    = db["products"]
    ingredients_col = db["ingredients"]

    # 1. Lookup tablolarını oluştur
    print("ingredients koleksiyonu yükleniyor...")
    lookup = build_lookup(ingredients_col)
    searchable_keys = list(lookup.keys())
    print(f"  → {len(lookup):,} benzersiz anahtar yüklendi.")

    # 2. Tüm products_ingredients'ları tara
    print("products koleksiyonu taranıyor...")
    total_products   = 0
    total_ingredients_seen = 0

    # unmatched: normalized_key → {original: set, products: set}
    unmatched: Dict[str, dict] = {}

    cursor = products_col.find({}, {"_id": 1, "name": 1, "product_ingredients": 1, "brand": 1})

    for product in cursor:
        total_products += 1
        ingredients_list = product.get("product_ingredients") or []
        product_id   = str(product.get("_id", ""))
        product_name = product.get("name", "")
        brand        = product.get("brand", "")

        for raw_ing in ingredients_list:
            if not isinstance(raw_ing, str):
                continue
            total_ingredients_seen += 1

            result = match_ingredient(raw_ing, lookup, searchable_keys)
            if result is not None:
                key = result["normalized"].lower()
                if key not in unmatched:
                    unmatched[key] = {
                        "original_values": set(),
                        "normalized": result["normalized"],
                        "found_in_products": []
                    }
                unmatched[key]["original_values"].add(raw_ing)
                unmatched[key]["found_in_products"].append({
                    "product_id": product_id,
                    "product_name": product_name,
                    "brand": brand
                })

        if total_products % 500 == 0:
            print(f"  {total_products} ürün işlendi, şu ana kadar {len(unmatched)} eşleşmeyen içerik...")

    print(f"\nTarama tamamlandı:")
    print(f"  Toplam ürün          : {total_products:,}")
    print(f"  Toplam içerik görülen: {total_ingredients_seen:,}")
    print(f"  Eşleşmeyen (benzersiz): {len(unmatched):,}")

    # 3. JSON'a yaz
    output = []
    for norm_key, data in sorted(unmatched.items(), key=lambda x: -len(x[1]["found_in_products"])):
        output.append({
            "normalized": data["normalized"],
            "original_values": sorted(data["original_values"]),
            "occurrence_count": len(data["found_in_products"]),
            "found_in_products": data["found_in_products"]
        })

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Eşleşmeyen {len(output)} benzersiz içerik '{OUTPUT_FILE}' dosyasına yazıldı.")
    print("   Bu içerikleri zenginleştirip ingredients koleksiyonuna ekleyebilirsiniz.")


if __name__ == "__main__":
    main()
