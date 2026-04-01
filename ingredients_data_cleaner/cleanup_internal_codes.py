import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
client = MongoClient(MONGO_URI)
db = client["kozmetik"]
collection = db["ingredients"]

def main():
    # inci_name null/boş ve name'i "internal code" (büyük/küçük harf bağımsız) ile başlayanlar
    query = {
        "$and": [
            {
                "$or": [
                    {"inci_name": None}, 
                    {"inci_name": ""}, 
                    {"inci_name": {"$exists": False}}
                ]
            },
            {
                "name": {"$regex": "^internal code", "$options": "i"} # Case-insensitive başlar
            }
        ]
    }
    
    cursor = collection.find(query)
    
    deleted_count = 0
    print("🧹 Tarama başlatılıyor: 'inci_name' null olan ve 'name' alanı 'internal code' ile başlayanlar aranıyor...\n")
    
    for doc in cursor:
        print(f"🗑 Siliniyor: ID={doc['_id']} | İsim: {doc.get('name', 'Bilinmiyor')} | Aliases: {doc.get('aliases', [])[:2]}")
        collection.delete_one({"_id": doc["_id"]})
        deleted_count += 1

    print(f"\n✅ Toplam {deleted_count} adet 'internal code' ile başlayan hatalı kayıt başarıyla veritabanından silindi.")

if __name__ == "__main__":
    main()
