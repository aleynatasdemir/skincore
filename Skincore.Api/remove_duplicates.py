#!/usr/bin/env python3
"""
remove_duplicates.py
Aynı barcode'a sahip ürünlerden ingredient sayısı az olanı siler.
Eşit ingredient sayısında en yeni eklenen (en büyük _id) korunur.

Kullanım:
    python3 remove_duplicates.py [--dry-run]
"""

import sys
from pymongo import MongoClient
from bson import ObjectId

MONGO_URI = "mongodb://localhost:27017/"
DB_NAME = "kozmetik"
COLLECTION = "products"

dry_run = "--dry-run" in sys.argv

client = MongoClient(MONGO_URI)
db = client[DB_NAME]
col = db[COLLECTION]

print(f"{'[DRY RUN] ' if dry_run else ''}Duplicate barcode tarama başlıyor...")

pipeline = [
    {"$match": {"barcode": {"$exists": True, "$ne": "", "$ne": None}}},
    {"$group": {
        "_id": "$barcode",
        "count": {"$sum": 1},
        "ids": {"$push": "$_id"}
    }},
    {"$match": {"count": {"$gt": 1}}}
]

duplicates = list(col.aggregate(pipeline))
print(f"Duplicate barcode grubu: {len(duplicates)}")

total_deleted = 0

for group in duplicates:
    barcode = group["_id"]
    ids = group["ids"]

    docs = list(col.find(
        {"_id": {"$in": ids}},
        {"_id": 1, "barcode": 1, "name": 1, "product_ingredients": 1}
    ))

    def ing_count(doc):
        ing = doc.get("product_ingredients", [])
        return len(ing) if isinstance(ing, list) else 0

    # En fazla ingredient'a sahip olanı koru; eşitse en büyük _id (en yeni) korunur
    docs.sort(key=lambda d: (ing_count(d), d["_id"]), reverse=True)

    keep = docs[0]
    to_delete = docs[1:]

    print(f"\nBarcode: {barcode}")
    print(f"  Korunan : {keep['_id']} — {keep.get('name','?')} ({ing_count(keep)} ing)")
    for d in to_delete:
        print(f"  Silinen  : {d['_id']} — {d.get('name','?')} ({ing_count(d)} ing)")

    if not dry_run:
        delete_ids = [d["_id"] for d in to_delete]
        result = col.delete_many({"_id": {"$in": delete_ids}})
        total_deleted += result.deleted_count

if dry_run:
    would_delete = sum(g["count"] - 1 for g in duplicates)
    print(f"\n[DRY RUN] Silinecek toplam ürün: {would_delete}")
else:
    print(f"\nSilinen toplam ürün: {total_deleted}")

client.close()
print("Tamamlandı.")
