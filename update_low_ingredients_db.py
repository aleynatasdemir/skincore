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

load_dotenv()

api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("Uyarı: GEMINI_API_KEY environment variable ayarlanmamış.")

client = genai.Client(api_key=api_key) if api_key else genai.Client()

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
        response = requests.get(url, impersonate="chrome110", timeout=15, headers=headers)
        response.raise_for_status()
        return Image.open(BytesIO(response.content))
    except Exception as e:
        print(f"❌ Fotoğraf indirme hatası: {e}")
        return None

def find_ingredients(product_name, image_url, product_id="", barcode=""):
    local_image_path = find_local_image(product_id, barcode)
    image = fetch_image(image_url, local_image_path)

    grounding_tool = types.Tool(google_search=types.GoogleSearch())
    config = types.GenerateContentConfig(tools=[grounding_tool], temperature=0.1)

    prompt_name = f"""Google'da '{product_name} ingredients' şeklinde ara ve bu kozmetik ürününün tam içerik listesini bul.

Sadece virgülle ayrılmış INCI içerik listesini döndür. Örnek: Aqua, Glycerin, Niacinamide, ...
Başka hiçbir şey yazma. İçerik listesini kesinlikle bulamazsan sadece BULUNAMADI yaz."""

    prompt_barcode = f"""Google'da '{barcode} ingredients' şeklinde ara ve bu barkod numarasına ait kozmetik ürününün tam içerik listesini bul.

Sadece virgülle ayrılmış INCI içerik listesini döndür. Örnek: Aqua, Glycerin, Niacinamide, ...
Başka hiçbir şey yazma. İçerik listesini kesinlikle bulamazsan sadece BULUNAMADI yaz."""

    if image:
        print("📷 Yerel/web fotoğraf bulundu.")
    else:
        print("⚠️ Fotoğraf bulunamadı.")

    def _call(prompt_text, with_image=False):
        contents = [prompt_text]
        if with_image and image:
            contents.append(image)
        return client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=config,
        )

    def _is_found(resp):
        t = resp.text.strip() if resp.text else ""
        return t and t.upper() != "BULUNAMADI"

    try:
        # 1. Ürün adı ile ara
        print("🔍 Ürün adı ile aranıyor...")
        response = _call(prompt_name)

        # 2. Bulunamadıysa ve görsel varsa, görsel ile tekrar dene
        if not _is_found(response) and image:
            print("📷 Görsel ile tekrar deneniyor...")
            response = _call(prompt_name, with_image=True)

        # 3. Hala bulunamadıysa ve barkod varsa, barkod ile ara
        if not _is_found(response) and barcode:
            print(f"🔎 Barkod ile aranıyor: {barcode}")
            time.sleep(2)
            response = _call(prompt_barcode)

        # 4. Barkod araması da başarısızsa ve görsel varsa, barkod+görsel ile dene
        if not _is_found(response) and barcode and image:
            print(f"📷 Barkod + görsel ile tekrar deneniyor...")
            response = _call(prompt_barcode, with_image=True)

        if hasattr(response, 'candidates') and response.candidates and \
           hasattr(response.candidates[0], 'grounding_metadata') and response.candidates[0].grounding_metadata:
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
            time.sleep(10)
            return "TEMP_ERROR"
        elif "429" in error_msg or "Quota" in error_msg or "exhausted" in error_msg:
            print(f"⏳ API Kotası veya Hız Sınırı Aşıldı (429)! 30 saniye bekleniyor...")
            time.sleep(30)
            return "TEMP_ERROR"
        print(f"❌ API hatası ({product_name}): {error_msg}")
        return "BULUNAMADI"

def validate_ingredients_with_ai(product_name, ingredients_list):
    """AI ile bulunan içerikleri doğrula - gerçekten bu ürüne ait mi?"""
    ingredients_str = ", ".join(ingredients_list)

    prompt = f"""
Kozmetik ürünü: '{product_name}'
Bulunan içerik listesi: {ingredients_str}

Bu içerik listesi gerçekten '{product_name}' ürününe ait mi? Aşağıdaki kriterlere göre değerlendir:

1. İçerikler INCI formatında mı? (Latince/İngilizce kimyasal adlar)
2. İçerik sayısı makul mü? (kozmetik ürünler genelde 5-50 arası içerik içerir)
3. Ürün türüyle uyumlu içerikler var mı? (örn. şampuanda surfactant, kremde emollient vb.)
4. Türkçe açıklamalar, cümleler veya pazarlama metni içeriyor mu? (içermemeli)
5. Gerçek bir INCI listesi gibi görünüyor mu, yoksa uydurulmuş/genel mu?

Eğer bu liste gerçek ve bu ürüne ait görünüyorsa: sadece "ONAYLANDI" yaz.
Eğer şüpheliysen veya yanlış görünüyorsa: sadece "REDDEDİLDİ" yaz.
Başka hiçbir şey yazma.
"""

    try:
        validation_config = types.GenerateContentConfig(temperature=0.0)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[prompt],
            config=validation_config,
        )
        result = response.text.strip().upper() if response.text else "REDDEDİLDİ"
        return "ONAYLANDI" in result
    except Exception as e:
        print(f"⚠️ Doğrulama hatası: {e}")
        return True  # Hata varsa geç, engelleme

def update_database_directly(max_ingredients=10):
    print(f"Veritabanından içeriği {max_ingredients}'dan az olan ürünler taranıyor...")

    # Admin panel ile aynı sorgu:
    # is_ingredient_checked != True VE (product_ingredients.size < 10 VEYA product_ingredients yok)
    query = {
        "is_ingredient_checked": {"$ne": True},
        "$or": [
            {"$expr": {"$lt": [{"$size": {"$ifNull": ["$product_ingredients", []]}}, max_ingredients]}},
            {"product_ingredients": {"$exists": False}}
        ]
    }

    total_to_process = col.count_documents(query)
    print(f"Toplam işlem yapılacak ürün sayısı: {total_to_process}")

    products = col.find(query)

    total_processed = 0
    total_updated = 0
    total_rejected = 0

    for db_product in products:
        p_id = db_product.get('_id')
        p_name = db_product.get('name', 'İsimsiz Ürün')
        p_barcode = db_product.get('barcode', '')

        # Resim URL'sini bul
        p_image_raw = ""
        im_urls = db_product.get("image_urls")
        if im_urls and isinstance(im_urls, list) and len(im_urls) > 0:
            first = im_urls[0]
            if isinstance(first, dict):
                p_image_raw = first.get("fileUrl") or first.get("fileName") or first.get("url") or first.get("src") or ""
            elif isinstance(first, str):
                p_image_raw = first
        elif im_urls and isinstance(im_urls, str):
            p_image_raw = im_urls
        elif db_product.get("image_url"):
            p_image_raw = db_product.get("image_url")

        if isinstance(p_image_raw, dict):
            p_image = p_image_raw.get("fileUrl", "") or p_image_raw.get("fileName", "") or ""
        elif isinstance(p_image_raw, str):
            p_image = p_image_raw
        else:
            p_image = ""

        print(f"\n[{total_processed + 1}/{total_to_process}] Aratılıyor: {p_name}")

        time.sleep(4)

        ingredients_text = find_ingredients(p_name, p_image, product_id=p_id, barcode=p_barcode)

        if ingredients_text == "TEMP_ERROR":
            print(f"🔄 Yoğunluktan ötürü atlandı, bir sonraki çalışmada tekrar denenecek.")
            continue  # is_ingredient_checked'ı güncelleme, tekrar denensin

        # BULUNAMADI ise işaretleme - tekrar denenebilsin
        if not ingredients_text or ingredients_text.upper() == "BULUNAMADI":
            print(f"-> BULUNAMADI. is_ingredient_checked güncellenmedi (tekrar denenebilir).")
            total_processed += 1
            continue

        # Metin kalitesi kontrolü: çok kısa veya Türkçe cümle içeriyor mu?
        if len(ingredients_text) < 30:
            print(f"-> Çok kısa metin ({len(ingredients_text)} karakter), reddedildi.")
            total_processed += 1
            total_rejected += 1
            continue

        # Virgülle ayır ve temizle
        raw_list = [i.strip() for i in ingredients_text.split(',') if i.strip()]

        # Minimum 5 içerik şartı
        if len(raw_list) < 5:
            print(f"-> Yetersiz içerik sayısı ({len(raw_list)}), reddedildi.")
            total_processed += 1
            total_rejected += 1
            continue

        # Türkçe cümle/açıklama içeriyor mu? (INCI listesi olmamalı)
        turkish_keywords = [" ve ", " ile ", " için ", " olan ", " içeren ", " bulunur", " içerir", "madde", "bileşen"]
        has_turkish = any(kw in ingredients_text.lower() for kw in turkish_keywords)
        if has_turkish:
            print(f"-> Türkçe açıklama metni tespit edildi, reddedildi.")
            total_processed += 1
            total_rejected += 1
            continue

        # Her içeriğin makul uzunlukta olup olmadığını kontrol et
        suspicious = [i for i in raw_list if len(i) > 80 or len(i) < 2]
        if len(suspicious) > 2:
            print(f"-> Şüpheli içerikler tespit edildi ({len(suspicious)} adet), reddedildi.")
            total_processed += 1
            total_rejected += 1
            continue

        # AI doğrulaması
        print(f"🔍 AI doğrulaması yapılıyor ({len(raw_list)} içerik)...")
        time.sleep(2)
        is_valid = validate_ingredients_with_ai(p_name, raw_list)

        if not is_valid:
            print(f"-> AI doğrulaması başarısız, reddedildi. is_ingredient_checked güncellenmedi.")
            total_processed += 1
            total_rejected += 1
            continue

        # Tüm kontroller geçti - veritabanını güncelle
        col.update_one(
            {"_id": ObjectId(p_id)},
            {
                "$set": {
                    "product_ingredients": raw_list,
                    "is_ingredient_checked": True,
                    "ai_updated_at": time.time()
                }
            }
        )
        print(f"-> ✅ GÜNCELLENDİ! {len(raw_list)} içerik bulundu ve doğrulandı.")
        print(raw_list[:5], "...")
        total_updated += 1
        total_processed += 1

    print(f"\n--- ÖZET ---")
    print(f"İşlenen: {total_processed}")
    print(f"Güncellenen: {total_updated}")
    print(f"Reddedilen: {total_rejected}")
    print(f"Bulunamayan/Atlanan: {total_processed - total_updated - total_rejected}")

if __name__ == "__main__":
    update_database_directly(max_ingredients=10)
    print("\nİşlem tamamlandı!")
