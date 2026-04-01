import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
client = MongoClient(MONGO_URI)
db = client["kozmetik"]
collection = db["ingredients"]

def is_sentence(text):
    # Eğer metin değilse atla
    if not text or not isinstance(text, str):
        return False
    
    words = text.split()
    # Veya metin uzunluğu çok fazlaysa (> 40 karakter)
    # Veya içinde 4'ten fazla kelime barındırıyorsa cümle olarak kabul edip siliyoruz
    if len(words) > 4 or len(text) > 40:
        return True
        
    return False

def main():
    # inci_name null, boş veya hiç tanımlanmamış olanları bul:
    query = {
        "$or": [
            {"inci_name": None}, 
            {"inci_name": ""}, 
            {"inci_name": {"$exists": False}}
        ]
    }
    
    cursor = collection.find(query)
    
    deleted_count = 0
    print("🧹 Tarama başlatılıyor: 'inci_name' null olan ve 'aliases' içinde cümle barındıranlar aranıyor...\n")
    
    for doc in cursor:
        aliases = doc.get("aliases", [])
        if aliases and isinstance(aliases, list):
            # Aliases içindeki herhangi bir string cümle kriterine uyuyorsa
            has_sentence = any(is_sentence(alias) for alias in aliases)
            
            if has_sentence:
                print(f"🗑 Siliniyor: ID={doc['_id']} | İsim: {doc.get('name', 'Bilinmiyor')} | Aliases: {aliases[:2]}...")
                collection.delete_one({"_id": doc["_id"]})
                deleted_count += 1

    print(f"\n✅ Toplam {deleted_count} adet cümle içeren hatalı kayıt başarıyla veritabanından silindi.")

if __name__ == "__main__":
    main()
