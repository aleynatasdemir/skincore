import os
import json
import time
from dotenv import load_dotenv
from pymongo import MongoClient
from google import genai
from google.genai import types

# .env dosyasındaki ortam değişkenlerini yükle
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
# En ideal model tavsiyesi: gemini-2.5-flash veya gemini-2.0-flash (hızlı, isabetli ve maliyet etkin)
# Daha derin analiz isterseniz: gemini-1.5-pro
MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite-preview")
BATCH_SIZE = int(os.getenv("BATCH_SIZE", 20))
DELAY_BETWEEN_BATCHES = int(os.getenv("DELAY_BETWEEN_BATCHES", 3))

# Gemini İstemcisi
client = genai.Client(api_key=GEMINI_API_KEY)

# MongoDB Bağlantısı
mongo_client = MongoClient(MONGO_URI)
db = mongo_client['kozmetik']

source_collection = db['ingredients']
target_collection = db['ingredients_cleaned'] # Temizlenmiş veriler için yeni koleksiyon

SYSTEM_INSTRUCTION = """
Sen uzman bir dermatolog, kozmetik kimyageri ve veri mühendisisin. Görevin, sana liste halinde gönderilen düzensiz, karmaşık ve tekrarlayan kozmetik içerik verilerini analiz etmek, uluslararası standartlara (INCI) göre temizlemek, zenginleştirmek ve kusursuz bir JSON formatında geri döndürmektir.

Aşağıdaki KURALLARA KESİNLİKLE uymalısın. Kuralların dışına çıkmak, yorum eklemek veya istenmeyen formatta yanıt vermek yasaktır.

38: ### KURALLAR:
39: 1. TEKİLLEŞTİRME VE İSİMLENDİRME (INCI): Gelen girdideki içerik ismini analiz et. Anahtar isim olarak KESİNLİKLE uluslararası INCI (International Nomenclature of Cosmetic Ingredients) adını kullan ("inci_name"). Eğer INCI adheresine yüksek bir güvenceyle ulaşılamıyorsa, kesinlikle uydurma yapma ve "inci_name" değerini `null` yap. Gelen orijinal adı ve bilinen diğer tüm eşanlamlıları, ticari adları veya renk kodlarını (Örn: CI 77891) "aliases" (takma adlar) dizisine ekle.
40: 2. AÇIKLAMA (DESCRIPTION): Gelen girdideki kötü çevrilmiş veya karmaşık açıklamayı düzelt. İçeriğin ne olduğunu, temel işlevini ve cilt üzerindeki etkisini anlatan, son kullanıcının anlayabileceği sadelikte, bilimsel olarak doğru ve akıcı Türkçe ile maksimum 3 cümlelik bir açıklama yaz.
3. CİLT TİPİ ANALİZİ: Sadece şu 7 standart cilt tipini kullan: ["Normal", "Kuru", "Yagli", "Karma", "Hassas", "Akneye_Meyilli", "Olgun"]. 
   - "good_for": İçeriğin KESİNLİKLE faydalı olduğu cilt tiplerini bu diziye ekle. Eğer belirgin bir faydası yoksa boş dizi [] bırak.
   - "bad_for": İçeriğin zarar verebileceği, tahriş edebileceği veya sivilce yapabileceği (örneğin yüksek komedojenik değer) cilt tiplerini bu diziye ekle. Zararsızsa boş dizi [] bırak.
4. METRİKLER: 
   - "comedogenic_rating": 0 ile 5 arasında bir tam sayı olmalıdır. (0: Tıkamaz, 5: Kesinlikle tıkar). Eğer bilimsel olarak bilinmiyorsa null değerini ver, asla uydurma.
   - "ewg_score": Girdide varsa düzenle (Örn: "1-2" veya "3"), yoksa kendi veri tabanından doğrula, bilmiyorsan null bırak.
   - "safety_label": İçeriğin güvenlik etiketini belirle. SADECE şu değerlerden biri olmalıdır: ["Tamamen Güvenli", "Güvenli", "Kabul Edilebilir", "Şüpheli", "Riskli"].
   - "safety_level": "safety_label" değerine karşılık gelen seviyeyi tam sayı (integer) olarak ver. (Tamamen Güvenli: 0, Güvenli: 1, Kabul Edilebilir: 2, Şüpheli: 3, Riskli: 4).
5. FONKSİYONLAR: İçeriğin kozmetik ürün içindeki işlevlerini (Örn: "Nemlendirici", "Koruyucu", "Emülgatör", "UV Filtresi") kısa etiketler halinde "functions" dizisine ekle.

### ÇIKTI FORMATI (JSON SCHEMA):
Yanıtın SADECE VE SADECE aşağıdaki JSON formatında olmalıdır. JSON yapısı dışında "İşte sonuçlar", "Merhaba" gibi hiçbir metin üretme. Eğer sana birden fazla içerik gönderirsem, bunları bir JSON dizisi (Array) içinde döndür.

[
  {
    "original_id": "string",
    "inci_name": "string",
    "aliases": ["string", "string"],
    "description": "string",
    "functions": ["string", "string"],
    "skin_compatibility": {
      "good_for": ["string"],
      "bad_for": ["string"]
    },
    "metrics": {
      "comedogenic_rating": "number veya null",
      "ewg_score": "string veya null",
      "safety_label": "string",
      "safety_level": "number"
    }
  }
]
"""

def clean_data():
    # Sadece daha önce işlenmemiş verileri almak isterseniz query'yi değiştirebilirsiniz
    all_raw_data = list(source_collection.find({}))
    total = len(all_raw_data)
    print(f"[{total}] adet içerik veritabanından çekildi.")

    if total == 0:
        print("İşlenecek veri yok.")
        return

    # Veriyi BATCH_SIZE (ör. 20) boyutunda parçalara böl (Batching işlemi)
    for i in range(0, total, BATCH_SIZE):
        batch = all_raw_data[i:i + BATCH_SIZE]
        batch_payload = []
        
        for doc in batch:
            # Model ObjectId'yi JSON string olarak düzgün işlemesi için formatlıyoruz
            # original_id'yi schema'ya ekledik ki model bize aynı ID ile geri dönsün, böylece eşleştirebiliriz.
            item = {
                "original_id": str(doc.get("_id", "")),
                "raw_name": doc.get("name", "") or doc.get("aciklama", ""),
                "description": doc.get("description", "") or doc.get("detay", ""),
                "functions": doc.get("functions", "")
            }
            batch_payload.append(item)
            
        json_payload_str = json.dumps(batch_payload, ensure_ascii=False, indent=2)
        prompt = f"Lütfen aşağıdaki {len(batch)} adet kozmetik içeriğini analiz et:\n\n{json_payload_str}"
        
        print(f"\nBatch {i//BATCH_SIZE + 1} gönderiliyor... ({i} - {i + len(batch)} arası içerikler)")
        
        try:
            # Yapılandırılmış Çıktı Ayarları ve Düşük Temperature
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_INSTRUCTION,
                    temperature=0.1, # Halüsinasyonu önlemek için düşük sıcaklık
                    response_mime_type="application/json" # Modelin sadece JSON dönmesini zorunlu kılıyoruz
                )
            )
            
            # API'den gelen string formatındaki JSON veriyi parse ediyoruz
            cleaned_data_array = json.loads(response.text)
            
            # 2. Aşama: Temizlenmiş veriyi veritabanına kaydetme / Güncelleme (Upsert)
            if cleaned_data_array and isinstance(cleaned_data_array, list):
                from pymongo import UpdateOne
                
                # Sadece inci_name bazında Unique (Tekil) kayıt tutmak için
                # target_collection.create_index("inci_name", unique=True) # İsteğe bağlı olarak index oluşturabilirsiniz
                
                operations = []
                for item in cleaned_data_array:
                    # 'inci_name' alanını baz alıyoruz. Eğer veritabanında bu INCI adına sahip bir kayıt 
                    # zaten varsa onu günceller, yoksa yepyeni bir kayıt olarak ekler.
                    # Böylece AŞLA kopya/duplicate veri oluşmaz.
                    find_query = {"inci_name": item.get("inci_name")}
                    update_data = {"$set": item}
                    operations.append(UpdateOne(find_query, update_data, upsert=True))
                
                if operations:
                    result = target_collection.bulk_write(operations)
                    print(f"  ✓ {result.upserted_count} yeni içerik eklendi, {result.modified_count} içerik güncellendi. Toplam işlenen: {len(operations)}")
            
        except Exception as e:
            print(f"  X Hata oluştu (Batch {i//BATCH_SIZE + 1}): {e}")
            # Bu hatalar log dosyasına da yazılabilir
            
        # API Rate Limitlere takılmamak için bekliyoruz
        if i + BATCH_SIZE < total:
            print(f"Rate limitleri aşmamak için {DELAY_BETWEEN_BATCHES} saniye bekleniyor...")
            time.sleep(DELAY_BETWEEN_BATCHES)

if __name__ == "__main__":
    print("Veri temizleme işlemi başlıyor...")
    clean_data()
    print("İşlem tamamlandı.")
