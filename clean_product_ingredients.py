#!/usr/bin/env python3
"""
product_ingredients temizleme scripti.

MongoDB'deki products koleksiyonundaki kirli product_ingredients arraylerini
temizler. Sorunlu formatlar:
  - "INGREDIENTS: Aqua, Glycerin, ..." → split edip array yap
  - "Aqua • Glycerin • ..." → bullet ile split
  - "#14593 Ingrediente: AQUA" → prefix kaldır
  - "" boş string → kaldır
  - Uzun virgüllü blob → split
  - Trailing noktalama (., ;) → kaldır

Kullanım:
  python3 clean_product_ingredients.py           # Dry-run (değişiklik yapmaz)
  python3 clean_product_ingredients.py --apply   # Gerçek güncelleme
"""

import re
import sys
from pymongo import MongoClient

MONGO_URI = "mongodb://localhost:27017/"
client = MongoClient(MONGO_URI)
col = client['kozmetik']['products']

# --- Regex kalıpları ---
HASH_PREFIX = re.compile(r'^#\d+\s*(ingrediente:\s*)?', re.IGNORECASE)
NUMERIC_PREFIX = re.compile(r'^\d{3,}\s+')  # "18311 AQUA" gibi
INGREDIENTS_PREFIX = re.compile(r'^INGREDIENTS\s*:\s*', re.IGNORECASE)


def clean_single_ingredient(s: str) -> str:
    """Tek bir ingredient string'ini temizler."""
    s = s.strip()
    
    # Control karakterleri kaldır (\x03 vb.)
    s = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', s)
    
    # #ID Ingrediente: prefix
    s = HASH_PREFIX.sub('', s)
    
    # INGREDIENTS: prefix (tek ingredient'e yapışmış olabilir)
    s = INGREDIENTS_PREFIX.sub('', s).strip()
    
    # Sayı prefix
    s = NUMERIC_PREFIX.sub('', s)
    
    # Trailing noktalama
    s = s.rstrip('.,; ')
    
    # Stray quotes: "Aqua veya Parfum" → Aqua / Parfum
    s = s.strip('"').strip()
    
    return s.strip()


def split_ingredient_string(s: str) -> list[str]:
    """
    Tek bir string'i ingredient array'ine çevirir.
    Farklı separator'lara göre split eder.
    """
    s = s.strip()
    
    # Control karakterleri kaldır
    s = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', s)
    
    if not s or s == '""':
        return []
    
    # #ID prefix (bullet split'ten önce kaldır — "#21463 INGREDIENTS :X • Y" gibi)
    s = HASH_PREFIX.sub('', s).strip()
    
    # INGREDIENTS: prefix kaldır
    s = INGREDIENTS_PREFIX.sub('', s).strip()
    
    # Bullet separator: • veya ·
    if '•' in s or '·' in s:
        parts = re.split(r'\s*[•·]\s*', s)
        return [clean_single_ingredient(p) for p in parts if p.strip()]
    
    # Uzun string ve virgül var → virgülle split
    # Ama kısa string'lerde virgül ingredient isminin parçası olabilir (ör: "CI 77891, CI 77492")
    # Bu yüzden sadece uzun string'lerde (>80 char) veya çok virgül varsa split yapıyoruz
    comma_count = s.count(',')
    if len(s) > 80 and comma_count >= 3:
        parts = [p.strip() for p in s.split(',')]
        return [clean_single_ingredient(p) for p in parts if p.strip()]
    
    # Tek ingredient
    cleaned = clean_single_ingredient(s)
    return [cleaned] if cleaned else []


def process_product(doc) -> tuple[bool, list[str]]:
    """
    Bir ürünün product_ingredients'ını temizler.
    Returns: (changed: bool, new_ingredients: list[str])
    """
    raw_ings = doc.get('product_ingredients', [])
    if not raw_ings:
        return False, []
    
    new_ings = []
    for ing in raw_ings:
        if not isinstance(ing, str):
            new_ings.append(str(ing))
            continue
        
        parts = split_ingredient_string(ing)
        new_ings.extend(parts)
    
    # Boş string'leri filtrele
    new_ings = [i for i in new_ings if i and i.strip()]
    
    # Değişiklik var mı?
    if new_ings == raw_ings:
        return False, new_ings
    
    return True, new_ings


def main():
    apply = '--apply' in sys.argv
    
    pipeline = [
        {'$match': {'product_ingredients': {'$exists': True, '$ne': []}}},
        {'$project': {'name': 1, 'product_ingredients': 1}}
    ]
    all_products = list(col.aggregate(pipeline))
    
    total = len(all_products)
    changed_count = 0
    split_count = 0  # Array büyüyen ürünler (split edilen)
    shrunk_count = 0  # Array küçülen (boş kaldırılan)
    
    examples = []
    
    for doc in all_products:
        changed, new_ings = process_product(doc)
        if changed:
            changed_count += 1
            old_count = len(doc.get('product_ingredients', []))
            new_count = len(new_ings)
            
            if new_count > old_count:
                split_count += 1
            elif new_count < old_count:
                shrunk_count += 1
            
            if len(examples) < 10:
                examples.append({
                    'name': doc.get('name', '?')[:50],
                    'old': doc['product_ingredients'][:3],
                    'new': new_ings[:5],
                    'old_count': old_count,
                    'new_count': new_count
                })
            
            if apply:
                col.update_one(
                    {'_id': doc['_id']},
                    {'$set': {'product_ingredients': new_ings}}
                )
    
    # Rapor
    mode = "APPLY (Güncellendi)" if apply else "DRY-RUN (Sadece analiz)"
    print(f"\n{'='*60}")
    print(f"  MOD: {mode}")
    print(f"{'='*60}")
    print(f"  Toplam ürün: {total}")
    print(f"  Değişiklik gereken: {changed_count}")
    print(f"    → Split edilen (array büyüdü): {split_count}")
    print(f"    → Kısalan (boş kaldırılan): {shrunk_count}")
    print(f"    → Diğer (prefix/suffix temizlendi): {changed_count - split_count - shrunk_count}")
    
    if examples:
        print(f"\n{'='*60}")
        print(f"  ÖRNEKLER (ilk {len(examples)})")
        print(f"{'='*60}")
        for ex in examples:
            print(f"\n  [{ex['name']}]")
            print(f"    Eski ({ex['old_count']} adet): {ex['old']}")
            print(f"    Yeni ({ex['new_count']} adet): {ex['new']}")
    
    if not apply and changed_count > 0:
        print(f"\n  ⚠️  Değişiklikleri uygulamak için: python3 clean_product_ingredients.py --apply")
    
    client.close()


if __name__ == '__main__':
    main()
