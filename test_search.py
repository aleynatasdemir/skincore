import json
import os
import glob
from io import BytesIO
from PIL import Image
from curl_cffi import requests
from google import genai
from google.genai import types

api_key = os.environ.get("GEMINI_API_KEY") 
if not api_key:
    print("Warning: GEMINI_API_KEY environment variable is not set. The search might fail.")

client = genai.Client()

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
    """Veritabanından indirilen daha önceki fotoğrafları db_ocr içinden bulmayı dener."""
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
                # İlk geçerli resmi(jpg, png vs) döndür
                for f in os.listdir(folder_path):
                    if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                        return os.path.join(folder_path, f)
    return None

def fetch_image(url, local_path=None):
    if local_path and os.path.exists(local_path):
        print(f"Resim yerel klasörden (db_ocr) alınıyor: {local_path}")
        return Image.open(local_path)
    
    try:
        if not url:
            return None
        
        headers = get_headers_for_url(url)
        print(f"Resim URL'den indiriliyor: {url}")
        
        response = requests.get(
            url,
            impersonate="chrome110", # Cloudflare geçmek için çok etkilidir!
            timeout=15,
            headers=headers
        )
        response.raise_for_status()
        return Image.open(BytesIO(response.content))
    except Exception as e:
        print(f"Resim indirme hatası: {e}")
        return None

def find_ingredients(product_name, image_url, product_id="", barcode=""):
    print(f"\n--- İşleniyor: {product_name} ---")
    
    local_image_path = find_local_image(product_id, barcode)
    image = fetch_image(image_url, local_image_path)
    
    if not image:
        print("Uyarı: Resimsiz arama yapılacak.")
    
    grounding_tool = types.Tool(
        google_search=types.GoogleSearch()
    )

    config = types.GenerateContentConfig(
        tools=[grounding_tool],
        temperature=0.1
    )

    prompt = f"""
    Lütfen Google'da arama yap ve kozmetik ürünü '{product_name}' için tam ve resmi içerik listesini (INCI listesini) bul.
    SADECE virgülle ayrılmış içerikleri veya temiz bir liste döndür. Ekstra açıklama veya giriş cümlesi yazma.
    """
    
    contents = [prompt]
    if image:
        contents.append(image)

    print("Gemini ile Google Grounding araması yapılıyor...")
    
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=config,
        )
        
        print("\nBulunan İçerikler:")
        print(response.text)
        
        if hasattr(response, 'candidates') and response.candidates and hasattr(response.candidates[0], 'grounding_metadata') and response.candidates[0].grounding_metadata:
            metadata = response.candidates[0].grounding_metadata
            if hasattr(metadata, 'grounding_chunks'):
                print("\nKullanılan Kaynaklar:")
                for chunk in metadata.grounding_chunks:
                    if hasattr(chunk, 'web') and hasattr(chunk.web, 'uri'):
                        print(f"- {chunk.web.uri}")
        
    except Exception as e:
        print(f"API hatası: {e}")

if __name__ == "__main__":
    file_path = "/Users/furkanyilmaz/Desktop/skincore/low_ingredient_products.json"
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    count = 0
    for product in data.get("products_by_ingredient_count", {}).get("7", []):
        find_ingredients(
            product['name'], 
            product.get('imageUrl', ''),
            product_id=product.get('id', ''),
            barcode=product.get('barcode', '')
        )
        count += 1
        if count >= 2:
            break
