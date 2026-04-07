import json
import os
import time
from io import BytesIO
from PIL import Image
from curl_cffi import requests
from google import genai
from google.genai import types
from pymongo import MongoClient
from bson.objectid import ObjectId
from dotenv import load_dotenv

# .env dosyasından değişkenleri yükle
load_dotenv()

api_key = os.environ.get("GEMINI_API_KEY") 
if not api_key:
    print("Uyarı: GEMINI_API_KEY environment variable ayarlanmamış. Lütfen .env dosyasına veya sisteme ekleyin.")

# API Key'i doğrudan client'a veriyoruz
client = genai.Client(api_key=api_key) if api_key else genai.Client()

# MongoDB Ayarları
MONGO_URI = "mongodb://localhost:27017/"
DB_NAME = "kozmetik"
COL_NAME = "products"

db_client = MongoClient(MONGO_URI)
col = db_client[DB_NAME][COL_NAME]

def get_headers_for_url(url: str) -> dict:
    headers = {
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    }
    if "watsons.com.tr" in url:
        headers["Referer"] = "https://www.watsons.com.tr/"
        headers["Origin"] = "https://www.watsons.com.tr"
    elif "sephora.com" in url:
        headers["Referer"] = "https://www.sephora.com.tr/"
        headers["Origin"] = "https://www.sephora.com.tr"
    elif "gratis.com" in url:
        headers["Referer"] = "https://www.gratis.com/"
    elif "rossmann" in url:
        headers["Referer"] = "https://www.rossmann.com.tr/"
    return headers

def find_local_image(product_id, barcode):
    candidates = [str(product_id), str(barcode)]
    base_dirs = [
        "/Users/furkanyilmaz/Desktop/skincore/db_ocr/images",
        "/Users/furkanyilmaz/Desktop/skincore/db_ocr/images_dermo"
    ]
    
    for base_dir in base_dirs:
        for cand in candidates:
            if not cand or cand == "None":
                continue
            folder_path = os.path.join(base_dir, cand)
            if os.path.isdir(folder_path):
                for f in os.listdir(folder_path):
                    if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                        return os.path.join(folder_path, f)
    return None

def fetch_image(url, local_path=None):
    if local_path and os.path.exists(local_path):
        print(f"📂 Yerel klasörden fotoğraf okundu: {local_path}")
        return Image.open(local_path)
    
    try:
        if not url:
            print("⚠️ İndirilecek bir fotoğraf URL'si yok.")
            return None
            
        if url.startswith("//"):
            url = "https:" + url
            
        print(f"🌍 Fotoğraf web'den indiriliyor: {url}")
        headers = get_headers_for_url(url)
        response = requests.get(
            url,
            impersonate="chrome110",
            timeout=15,
            headers=headers
        )
        response.raise_for_status()
        return Image.open(BytesIO(response.content))
    except Exception as e:
        print(f"❌ Fotoğraf indirme hatası: {e}")
        return None

def find_ingredients(product_name, image_url, product_id="", barcode=""):
    local_image_path = find_local_image(product_id, barcode)
    image = fetch_image(image_url, local_image_path)
    
    grounding_tool = types.Tool(
        google_search=types.GoogleSearch()
    )

    config = types.GenerateContentConfig(
        tools=[grounding_tool],
        temperature=0.1
    )

    prompt = f"""
    Lütfen Google'da arama yap ve kozmetik ürünü '{product_name}' için tam ve resmi içerik listesini (INCI listesini) bul.
    SADECE virgülle ayrılmış içerikleri döndür (örneğin: Aqua, Glycerin, Niacinamide, ...). 
    Eğer içerik listesini kesinlikle bulamıyorsan SADECE "BULUNAMADI" yaz, ekstra açıklama yapma.
    """
    
    contents = [prompt]
    if image:
        print("📷 Fotoğraf da eklendi, görsel ile birlikte arama yapılıyor...")
        contents.append(image)
    else:
        print("⚠️ Fotoğraf bulunamadı, sadece isim ile aranacak.")
    
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=config,
        )
        
        # Eklenen kaynakları console'a yazdır
        if hasattr(response, 'candidates') and response.candidates and hasattr(response.candidates[0], 'grounding_metadata') and response.candidates[0].grounding_metadata:
            metadata = response.candidates[0].grounding_metadata
            if hasattr(metadata, 'grounding_chunks') and metadata.grounding_chunks:
                print("🔗 Kullanılan Kaynaklar:")
                for chunk in metadata.grounding_chunks:
                    if hasattr(chunk, 'web') and hasattr(chunk.web, 'uri'):
                        print(f"  - {chunk.web.uri}")
                        
        if not response.text:
            return "BULUNAMADI"
            
        return response.text.strip()
    except Exception as e:
        error_msg = str(e)
        if "503" in error_msg or "UNAVAILABLE" in error_msg or "high demand" in error_msg:
            print(f"⏳ Gemini API yoğunluk hatası (503). 10 saniye bekleniyor...")
            time.sleep(10) # 10 saniye bekle
            return "TEMP_ERROR" # Hata var, sonraki döngüde tekrar denenmesi için işaret koy
            
        elif "429" in error_msg or "Quota" in error_msg or "exhausted" in error_msg:
            print(f"⏳ API Kotası veya Hız Sınırı Aşıldı (429)! 30 saniye bekleniyor...")
            time.sleep(30)
            return "TEMP_ERROR"

        print(f"❌ API hatası ({product_name}): {error_msg}")
        return "BULUNAMADI"  # Gerçekten çözülemeyen bir hataysa "bulunamadı" muamelesi yap

def update_database_directly(max_ingredients=10):
    print(f"Veritabanından içeriği {max_ingredients}'dan az olan ürünler taranıyor...")
    
    # IsIngredientChecked alanı True olmayan VE product_ingredients array'inin boyutu max_ingredients'dan küçük olanları bul
    query = {
        "IsIngredientChecked": {"$ne": True},
        "$expr": {
            "$lt": [{"$size": {"$ifNull": ["$product_ingredients", []]}}, max_ingredients]
        }
    }
    
    total_to_process = col.count_documents(query)
    print(f"Toplam işlem yapılacak ürün sayısı: {total_to_process}")
    
    products = col.find(query)
    
    total_processed = 0
    total_updated = 0

    for db_product in products:
        p_id = db_product.get('_id')
        p_name = db_product.get('name', 'İsimsiz Ürün')
        p_barcode = db_product.get('barcode', '')
        
        # Resim URL'sini bul ('image_urls' dizisi veya 'image_url' stringi olabilir)
        p_image_raw = ""
        im_urls = db_product.get("image_urls")
        
        if im_urls and isinstance(im_urls, list) and len(im_urls) > 0:
            p_image_raw = im_urls[0]
        elif im_urls and isinstance(im_urls, str):
            p_image_raw = im_urls
        elif db_product.get("image_url"):
            p_image_raw = db_product.get("image_url")
            
        p_image = ""
        if isinstance(p_image_raw, str):
            p_image = p_image_raw
        elif isinstance(p_image_raw, dict):
            p_image = p_image_raw.get("fileUrl", "") or p_image_raw.get("fileName", "") or p_image_raw.get("url", "") or p_image_raw.get("src", "") or ""
            
        # URL temizliği (eğer saçma bir format varsa atla)
        if not isinstance(p_image, str):
            p_image = ""
            
        print(f"\n[{total_processed}/{total_to_process}] Aratılıyor: {p_name}")
        
        # API İstek sınırı için bekleme süresi
        time.sleep(4)
        
        ingredients_text = find_ingredients(p_name, p_image, product_id=p_id, barcode=p_barcode)
        
        if ingredients_text == "TEMP_ERROR":
            print(f"🔄 {p_name} ürünü yoğunluktan ötürü atlandı, bir sonraki çalışmada tekrar denenecek.")
            continue # Veritabanını güncelleme, atla!
            
        if ingredients_text and ingredients_text.upper() != "BULUNAMADI" and len(ingredients_text) > 10:
            # Virgülle ayrılmış metni listeye çevirip temizleyelim
            new_ingredients_list = [i.strip() for i in ingredients_text.split(',') if i.strip()]
            
            if len(new_ingredients_list) > 2: # Mantıklı bir liste döndüyse
                col.update_one(
                    {"_id": ObjectId(p_id)},
                    {
                        "$set": {
                            "product_ingredients": new_ingredients_list,
                            "IsIngredientChecked": True,
                            "ai_updated_at": time.time()
                        }
                    }
                )
                print(f"-> GÜNCELLENDİ! {len(new_ingredients_list)} içerik bulundu.")
                print(new_ingredients_list[:5], "...")
                total_updated += 1
            else:
                print("-> Kısa/Geçersiz metin döndü, güncellenmedi.")
                col.update_one({"_id": ObjectId(p_id)}, {"$set": {"IsIngredientChecked": True}})
        else:
            print("-> BULUNAMADI.")
            col.update_one({"_id": ObjectId(p_id)}, {"$set": {"IsIngredientChecked": True}})
            
        total_processed += 1

if __name__ == "__main__":
    update_database_directly(max_ingredients=10) # 10'dan az içeriği olanları bulur
    print("\nİşlem tamamlandı!")
