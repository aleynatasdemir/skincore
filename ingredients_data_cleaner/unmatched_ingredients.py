import os
import json
import time
import warnings
from dotenv import load_dotenv
from pymongo import MongoClient, UpdateOne
from google import genai
from google.genai import types

# Kütüphane uyarılarını (FutureWarning vb.) gizle
warnings.filterwarnings("ignore")

# =========================
# ENV LOAD
# =========================
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")

# 50 içerik tek seferde gönderilince model tembelleşebiliyor 
# (JSON'u yarıda kesme veya array'in sadece ilk 15 elemanını dönme gibi hatalar)
# Bu nedenle optimum Batch boyutunu düşürüyoruz:
BATCH_SIZE = 20 
MAX_RETRIES = 3 # 503 Hatasında tekrar deneme sayısı
DELAY_BETWEEN_BATCHES = 2

# =========================
# SYSTEM PROMPT
# =========================
SYSTEM_INSTRUCTION = """
Sen uzman bir dermatolog, kozmetik kimyageri ve veri mühendisisin. Görevin, sana verilen kozmetik içerik isimlerini analiz ederek uluslararası INCI standartlarına uygun, bilimsel olarak doğru ve güvenilir bir JSON çıktısı üretmektir.

Amaç: Eksik veya düzensiz ingredient verisini normalize etmek, anlamlandırmak ve güvenilir şekilde zenginleştirmek.

GENEL KURALLAR:
- ASLA uydurma bilgi üretme. Bilinmiyorsa null veya [] kullan.
- Çıktı KESİNLİKLE JSON DİZİSİ (Array) olmalı.
- Eşleştirme için gönderilen "original_id" yi çıktıda KESİNLİKLE aynen koru. 
- Sana kaç adet obje gönderildiyse, cevap dizisinde de BİREBİR O KADAR obje bulunmalıdır. Eksik bırakma.

İSİMLENDİRME:
- INCI adı bul ("inci_name"). Bulamazsan orijinal adın kendisini koy, boş bırakma.
- "name" alanına da anlamlı, düzgün yazılmış temel adını koy (Örn; "Aqua").
- "aliases" içine sana gönderilen varyasyonları ve bilinen farklı dillerdeki isimlerini ekle.

AÇIKLAMA ("description"):
- Sağlıkla ve kozmetikle alakasını anlatan maks 3 cümle net Türkçe açıklama.

FONKSİYON ("functions"):
- Kısa etiketler (Örn: ["Nemlendirici", "Çözücü", "Kıvam Arttırıcı"]).

CİLT TİPİ ("skin_compatibility"):
- Sadece şu etiketlerden uygun olanları seç: ["Normal","Kuru","Yagli","Karma","Hassas","Akneye_Meyilli","Olgun"]

METRİKLER ("metrics"):
- "comedogenic_rating": 0-5 arası tam sayı veya null
- "ewg_score": dize (örn: "1", "1-2" vb.) veya null
- "safety_label": ["Tamamen Güvenli", "Güvenli", "Kabul Edilebilir", "Şüpheli", "Riskli"] aralığından uygun olanı seç.
- "safety_level": 0-4 arası tam sayı (default 2)

DÖNÜŞ FORMATI SADECE AŞAĞIDAKİ ŞEMA GİBİ OLMALIDIR:
[
  {
    "original_id": "string (gelen id aynen koruncak)",
    "inci_name": "string",
    "name": "string",
    "aliases": ["string"],
    "description": "string",
    "functions": ["string"],
    "skin_compatibility": {
      "good_for": ["string"],
      "bad_for": ["string"]
    },
    "metrics": {
      "comedogenic_rating": 0,
      "ewg_score": "1",
      "safety_label": "Kabul Edilebilir",
      "safety_level": 2
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
    try:
        with open("unmatched_ingredients.json", "r", encoding="utf-8") as f:
            all_ingredients = json.load(f)
    except FileNotFoundError:
        print("❌ 'unmatched_ingredients.json' dosyası bulunamadı. Lütfen önce tarama scriptini çalıştırın.")
        return

    # Zaten veritabanında olan kayıtları (script çöktüğünde vs) atlamak için listeleyelim.
    print("Veritabanından daha önce kaydedilmiş içerikler alınıyor...")
    seen_keys = set()
    for doc in collection.find({}, {"inci_name": 1, "name": 1, "aliases": 1}):
        for field in ("inci_name", "name"):
            val = doc.get(field)
            if val:
                seen_keys.add(val.lower().strip())
        for alias in doc.get("aliases") or []:
            if alias:
                seen_keys.add(alias.lower().strip())

    items_to_process = []
    for ing in all_ingredients:
        norm_key = ing.get("normalized", "").lower().strip()
        # Eğer bu normalize key halihazırda listemizde varsa bir daha istek atmayız
        if norm_key in seen_keys:
            continue
        items_to_process.append(ing)

    total_skipped = len(all_ingredients) - len(items_to_process)
    total = len(items_to_process)
    
    print(f"Zaten işlenmiş olduğu için atlanan: {total_skipped}")
    print(f"Toplam {total} yeni eşleşmeyen içerik zenginleştirilecek.\n")

    if total == 0:
        print("🎉 İşlenecek yeni içerik yok, tümü zaten veritabanında mevcut!")
        return

    for i in range(0, total, BATCH_SIZE):
        batch = items_to_process[i : i + BATCH_SIZE]
        
        # Token israfını önlemek için daraltılmış dictionary:
        batch_payload = []
        for ing in batch:
            batch_payload.append({
                "original_id": ing.get("normalized"), # Dönüşleri tanımak için
                "raw_name": ing.get("normalized"),
                "variations": ing.get("original_values", [])[:3] # Sadece ilk 3 varyasyonu gönder (token dostu)
            })

        print(f"🚀 Batch {i//BATCH_SIZE + 1} gönderiliyor... ({i} - {i + len(batch)} arası içerikler)")
        
        prompt = f"Lütfen aşağıdaki {len(batch)} adet içeriği analiz et ve hiçbir objeyi atlama:\n\n{json.dumps(batch_payload, ensure_ascii=False)}"

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
                
                # Model Düz JSON texti döndürür
                text_result = response.text
                if text_result.startswith("```json"):
                    text_result = text_result.replace("```json", "").replace("```", "").strip()
                
                data_array = json.loads(text_result)

                if isinstance(data_array, list) and len(data_array) > 0:
                    operations = []
                    for item in data_array:
                        item.pop("original_id", None) # Geri veritabanına eklemiyoruz
                        
                        match_key = item.get("inci_name") or item.get("name")
                        if not match_key:
                            continue
                            
                        item["name_upper"] = match_key.upper()
                        
                        find_query = {"inci_name": match_key}
                        operations.append(UpdateOne(find_query, {"$set": item}, upsert=True))

                    if operations:
                        result = collection.bulk_write(operations)
                        print(f"  ✅ {result.upserted_count} yeni eklendi, {result.modified_count} güncellendi. Toplam işlenen: {len(operations)} / Gönderilen: {len(batch)}")
                else:
                    print("  ⚠️ API'den boş liste veya beklenmeyen format geldi.")
                
                success = True
                break # Hata vermeden buraya geldiysek döngüden çık, Sonraki batch'e geç

            except Exception as e:
                print(f"  ⚠️ Hata (Deneme {attempt + 1}/{MAX_RETRIES}): {e}")
                time.sleep(3) # Retry öncesi bir süre dinlenmek şart
                
        if not success:
            print(f"  ❌ Batch {i//BATCH_SIZE + 1} tüm denemelere rağmen atlanıyor.")
        
        time.sleep(DELAY_BETWEEN_BATCHES)

    print("\n🎉 Tüm zenginleştirme süreci tamamlandı!")

if __name__ == "__main__":
    main()