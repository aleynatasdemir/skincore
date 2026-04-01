import os
import json
import time
import warnings
from dotenv import load_dotenv
from pymongo import MongoClient, UpdateOne
from bson import ObjectId
from google import genai
from google.genai import types

# Uyarıları gizle
warnings.filterwarnings("ignore")

# =========================
# ENV LOAD
# =========================
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")

BATCH_SIZE = 20 
MAX_RETRIES = 3 
DELAY_BETWEEN_BATCHES = 2

# =========================
# SYSTEM PROMPT
# =========================
SYSTEM_INSTRUCTION = """
Sen uzman bir kozmetik kimyageri ve medikal çevirmensin. 
Sana bir dizi kozmetik içeriği JSON objesi olarak gönderilecek. İçinde içeriklerin Türkçe açıklaması (description) ve Türkçe cilt uyumlulukları (skin_compatibility -> good_for, bad_for) bulunuyor.
Görevin, bu verileri profesyonel ve medikal İngilizceye çevirerek geriye sadece çevirileri içeren bir JSON dizisi döndürmektir.

ÇEVİRİ KURALLARI:
1. Çıktı sadece ve sadece JSON dizisi (Array) olmalı. Size gönderilen her obje için BİREBİR karşılık gelen 1 adet çıktı objesi dönmelisiniz. (Eksik obje döndürme)
2. Objelerin "id" değerini çıktıda AYNEN KORU. (Bu bizim MongoDB _id değerimizdir, eşleştirmede kullanılacak).
3. "description_en" alanı: Gelen Türkçe açıklamanın kusursuz ve profesyonel İngilizce kozmetik terminolojisine uygun şekilde çevrilmiş halidir.
4. "skin_compatibility_en" alanı: "good_for" ve "bad_for" dizilerinin İngilizce karşılıklarla doldurulmuş hali.

CİLT TİPİ KESİN ÇEVİRİ ZORUNLULUĞU:
skin_compatibility içindeki Türkçe kelimeleri BİREBİR şu İngilizce karşılıklarıyla (array item olarak) çevirmelisin. Mükemmel eşleştir ve asla başka bir kelime/varyasyon kullanma:
- "Normal" -> "Normal"
- "Kuru" -> "Dry"
- "Yagli" -> "Oily"
- "Karma" -> "Combination"
- "Hassas" -> "Sensitive"
- "Akneye_Meyilli" -> "Acne_Prone"
- "Olgun" -> "Mature"

Eğer bir içerik boş dizi `[]` veya null gönderilmişse, sonucu da boş dizi veya null olarak bırak.

ÇIKTI JSON ŞEMASI ÖRNEĞİ:
[
  {
    "id": "69ad910...",
    "description_en": "A powerful humectant that attracts moisture to the skin...",
    "skin_compatibility_en": {
      "good_for": ["Dry", "Combination"],
      "bad_for": ["Sensitive"]
    }
  }
]
"""

# =========================
# GEMINI SETUP
# =========================
client_gemini = genai.Client(api_key=GEMINI_API_KEY)
MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-3.1-flash")

# =========================
# MONGO SETUP
# =========================
client = MongoClient(MONGO_URI)
db = client["kozmetik"]
collection = db["ingredients"]

# =========================
# MAIN PIPELINE
# =========================
def main():
    # description_en alanı hiç oluşturulmamış (yani henüz çevrilmemiş) içerikleri bul
    query = {"description_en": {"$exists": False}}
    cursor = collection.find(query, {"_id": 1, "description": 1, "skin_compatibility": 1})
    
    items = list(cursor)
    total = len(items)
    
    # Tanımlı id ve geçerli description formatı olmayan kayıtları temizle
    print(f"Toplam {total} adet çevirisi eklenecek/bekleyen içerik bulundu.\n")

    if total == 0:
        print("🎉 Tüm içeriklerin çevirisi zaten tamamlanmış durumda!")
        return

    for i in range(0, total, BATCH_SIZE):
        batch = items[i : i + BATCH_SIZE]
        
        # Modele sadece çeviriye yarayacak dataları yolluyoruz:
        batch_payload = []
        for doc in batch:
            batch_payload.append({
                "id": str(doc["_id"]),
                "description": doc.get("description", ""),
                "skin_compatibility": doc.get("skin_compatibility", {"good_for": [], "bad_for": []})
            })

        print(f"🚀 Çeviri Batch {i//BATCH_SIZE + 1} gönderiliyor... ({i} - {i + len(batch)} arası)")
        prompt = f"Lütfen aşağıdaki {len(batch)} adet içeriği İngilizceye çevir ve eksiksiz array dön:\n\n{json.dumps(batch_payload, ensure_ascii=False)}"

        success = False
        for attempt in range(MAX_RETRIES):
            try:
                response = client_gemini.models.generate_content(
                    model=MODEL_NAME,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_INSTRUCTION,
                        temperature=0.1,  
                        response_mime_type="application/json"
                    )
                )
                
                text_result = response.text
                if text_result.startswith("```json"):
                    text_result = text_result.replace("```json", "").replace("```", "").strip()
                
                data_array = json.loads(text_result)

                if isinstance(data_array, list) and len(data_array) > 0:
                    operations = []
                    for item in data_array:
                        obj_id = item.get("id")
                        if not obj_id:
                            continue
                            
                        update_fields = {}
                        if "description_en" in item:
                            update_fields["description_en"] = item["description_en"]
                        if "skin_compatibility_en" in item:
                            update_fields["skin_compatibility_en"] = item["skin_compatibility_en"]
                            
                        # MongoDB Veritabanını Güncelle
                        if update_fields:
                            operations.append(UpdateOne(
                                {"_id": ObjectId(obj_id)},
                                {"$set": update_fields} # Yeni alanları doğrudan root içine gömüyoruz
                            ))

                    if operations:
                        result = collection.bulk_write(operations)
                        print(f"  ✅ {result.modified_count} verinin İngilizce çevirisi kaydedildi. (Okunan: {len(data_array)})")
                else:
                    print("  ⚠️ API'den boş liste geldi. Atlanıyor.")
                
                success = True
                break # Hata yoksa döngüden çık, bu batch başarılı

            except Exception as e:
                print(f"  ⚠️ Hata (Deneme {attempt + 1}/{MAX_RETRIES}): {e}")
                time.sleep(3)
                
        if not success:
            print(f"  ❌ Batch {i//BATCH_SIZE + 1} tüm denemelere rağmen başarısız oldu, atlanıyor.")
        
        # Batch'ler arası nefes payı
        time.sleep(DELAY_BETWEEN_BATCHES)

    print("\n🎉 Tüm veritabanı İngilizce (en) çeviri işlemleri tamamlandı!")

if __name__ == "__main__":
    main()
