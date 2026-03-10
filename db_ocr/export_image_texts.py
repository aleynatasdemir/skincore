#!/usr/bin/env python3
"""
MongoDB local/production koleksiyonundaki image_text alanı dolu olan
ürünleri barcode ile birlikte JSON dosyasına yazar.

Çıktı: db_ocr/image_texts.json
"""

import json
import os
from pymongo import MongoClient

MONGO_URI = "mongodb://localhost:27017/"
DB_NAME   = "local"
COL_NAME  = "production"
OUTPUT    = os.path.join(os.path.dirname(__file__), "image_texts.json")


def main():
    client = MongoClient(MONGO_URI)
    col = client[DB_NAME][COL_NAME]

    cursor = col.find(
        {"image_text": {"$exists": True, "$ne": ""}},
        {"barcode": 1, "gratis_id": 1, "image_text": 1, "_id": 0},
    )

    results = []
    for doc in cursor:
        results.append({
            "barcode": doc.get("barcode", ""),
            "gratis_id": doc.get("gratis_id", ""),
            "image_text": doc.get("image_text", ""),
        })

    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"✅ {len(results)} ürün yazıldı → {OUTPUT}")
    client.close()


if __name__ == "__main__":
    main()
