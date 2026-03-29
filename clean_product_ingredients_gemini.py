#!/usr/bin/env python3
"""
Gemini 3 Flash ile tüm ürünlerin product_ingredients alanını temizler.

Her batch'te 20 ürünün ingredient listesi Gemini'ye gönderilir.
Gemini her ingredient'i INCI standardına göre düzeltir:
  - "Krem Boya: Aqua" → "Aqua"
  - "INGREDIENTS: Glycerin, Niacinamide" → ["Glycerin", "Niacinamide"]
  - "Aqua/Water/Eau" → "Aqua"
  - Türkçe açıklamaları, bölüm başlıklarını, ürün kodlarını kaldırır
  - Yazım hatalarını düzeltir

Kullanım:
  python3 clean_product_ingredients_gemini.py              # İlk 2 batch test
  python3 clean_product_ingredients_gemini.py --all        # Tüm ürünler
  python3 clean_product_ingredients_gemini.py --all --dry   # Tümünü göster ama kaydetme
"""

import os
import sys
import json
import time
from dotenv import load_dotenv
from pymongo import MongoClient
from google import genai
from google.genai import types

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
MODEL_NAME = "gemini-3.1-flash-lite-preview"
BATCH_SIZE = 100
DELAY_BETWEEN_BATCHES = 2  # saniye

# Gemini client
ai_client = genai.Client(api_key=GEMINI_API_KEY)

# MongoDB
mongo_client = MongoClient(MONGO_URI)
db = mongo_client['kozmetik']
products_col = db['products']

SYSTEM_INSTRUCTION = """\
Sen bir kozmetik INCI (International Nomenclature of Cosmetic Ingredients) uzmanısın.

Sana bir ürünün içerik (ingredient) listesi verilecek. Görevin:

1. **Her ingredient'i standart INCI formatına çevir.** Büyük/küçük harf düzelt (Title Case kullan, CI kodları hariç).
2. **Bölüm başlıklarını kaldır.** "Krem Boya:", "Hair Color Cream:", "Oksidan Krem:", "INGREDIENTS:", "+/- MAY CONTAIN:" gibi prefix'ler ingredient değildir — bunları kaldır ama sonrasındaki ingredient'leri koru.
3. **Birleşik ingredient'leri ayır.** "Aqua/Water/Eau" → sadece "Aqua" yaz (INCI standardı). "Parfum/Fragrance" → "Parfum".
4. **Junk girdileri tamamen sil.** Şunlar ingredient DEĞİLDİR: Türkçe/Fransızca/Almanca açıklamalar, "lütfen kontrol ediniz", ürün kodları (F.I.L, B197049), HTML (&nbsp), sayılar, "N/A", "Vegan", marka isimleri.
5. **Yazım hatalarını düzelt.** "Phnoxyethanol" → "Phenoxyethanol", "Allotoin" → "Allantoin" vb.
6. **Trailing *, **, footnote işaretlerini kaldır.** "Glycerin*" → "Glycerin".
7. **Boş ve anlamsız girdileri kaldır.**

ÇIKTI FORMATI: Sadece JSON array dön. Her eleman {"id": "...", "ingredients": [...]} formatında.
JSON dışında hiçbir metin üretme. Markdown code fence kullanma.
"""


def process_batch(batch: list[dict]) -> list[dict] | None:
    """Bir batch ürünü Gemini'ye gönder, temizlenmiş ingredient listelerini al."""
    
    payload = []
    for doc in batch:
        payload.append({
            "id": str(doc["_id"]),
            "name": doc.get("name", ""),
            "ingredients": doc.get("product_ingredients", [])
        })
    
    prompt = f"Aşağıdaki {len(batch)} ürünün ingredient listelerini temizle:\n\n{json.dumps(payload, ensure_ascii=False)}"
    
    try:
        response = ai_client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION,
                temperature=0.05,
                response_mime_type="application/json"
            )
        )
        
        text = response.text
        if not text:
            print(f"  ✗ Gemini boş yanıt döndü")
            return None
        text = text.strip()
        # Gemini bazen birden fazla JSON bloğu dönüyor, sadece ilkini al
        decoder = json.JSONDecoder()
        result, _ = decoder.raw_decode(text)
        if isinstance(result, list):
            return result
        return None
        
    except Exception as e:
        print(f"  ✗ Gemini hatası: {e}")
        return None


def main():
    run_all = "--all" in sys.argv
    dry_run = "--dry" in sys.argv
    
    # İşlenmemiş ürünleri çek (her zaman temizlenenleri atla)
    query = {
        "product_ingredients": {"$exists": True, "$ne": []},
        "_gemini_cleaned": {"$ne": True}
    }
    
    all_products = list(products_col.find(
        query, 
        {"_id": 1, "name": 1, "product_ingredients": 1}
    ))
    
    total = len(all_products)
    if not run_all:
        # Test modunda sadece ilk 2 batch
        all_products = all_products[:BATCH_SIZE * 2]
    
    print(f"{'='*60}")
    print(f"  Model: {MODEL_NAME}")
    print(f"  Mod: {'DRY-RUN' if dry_run else 'APPLY'}")
    print(f"  Toplam ürün: {total}")
    print(f"  İşlenecek: {len(all_products)}")
    print(f"  Batch boyutu: {BATCH_SIZE}")
    print(f"  Tahmini batch: {(len(all_products) + BATCH_SIZE - 1) // BATCH_SIZE}")
    print(f"{'='*60}\n")
    
    updated = 0
    errors = 0
    unchanged = 0
    
    for i in range(0, len(all_products), BATCH_SIZE):
        batch = all_products[i:i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        total_batches = (len(all_products) + BATCH_SIZE - 1) // BATCH_SIZE
        
        print(f"[Batch {batch_num}/{total_batches}] {len(batch)} ürün gönderiliyor...", end=" ", flush=True)
        
        result = process_batch(batch)
        
        if result is None:
            errors += len(batch)
            print("✗ HATA")
            time.sleep(5)  # Hata sonrası daha uzun bekle
            continue
        
        # Sonuçları eşleştir ve güncelle
        result_map = {r["id"]: r.get("ingredients", []) for r in result}
        batch_updated = 0
        
        for doc in batch:
            doc_id = str(doc["_id"])
            if doc_id in result_map:
                new_ings = result_map[doc_id]
                old_ings = doc.get("product_ingredients", [])
                
                if new_ings != old_ings:
                    batch_updated += 1
                    
                    if not dry_run:
                        products_col.update_one(
                            {"_id": doc["_id"]},
                            {
                                "$set": {
                                    "product_ingredients": new_ings,
                                    "_gemini_cleaned": True
                                }
                            }
                        )
                    else:
                        # Dry-run: ilk birkaç örneği göster
                        if updated + batch_updated <= 5:
                            print(f"\n    [{doc.get('name','')[:40]}]")
                            print(f"      Eski ({len(old_ings)}): {old_ings[:3]}")
                            print(f"      Yeni ({len(new_ings)}): {new_ings[:3]}")
                else:
                    if not dry_run:
                        products_col.update_one(
                            {"_id": doc["_id"]},
                            {"$set": {"_gemini_cleaned": True}}
                        )
                    unchanged += 1
        
        updated += batch_updated
        print(f"✓ {batch_updated} değişti, {len(batch) - batch_updated} aynı")
        
        # Rate limit koruması
        if i + BATCH_SIZE < len(all_products):
            time.sleep(DELAY_BETWEEN_BATCHES)
    
    print(f"\n{'='*60}")
    print(f"  SONUÇ")
    print(f"{'='*60}")
    print(f"  Güncellenen: {updated}")
    print(f"  Değişmeyen: {unchanged}")
    print(f"  Hata: {errors}")
    if dry_run:
        print(f"\n  ⚠️  DRY-RUN modu — değişiklik kaydedilmedi.")
        print(f"  Uygulamak için: python3 clean_product_ingredients_gemini.py --all")
    
    mongo_client.close()


if __name__ == "__main__":
    if not GEMINI_API_KEY:
        print("HATA: GEMINI_API_KEY ortam değişkeni tanımlı değil!")
        print("  export GEMINI_API_KEY='your-api-key'")
        print("  veya .env dosyasına ekleyin")
        sys.exit(1)
    
    main()
