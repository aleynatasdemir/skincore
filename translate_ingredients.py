import pymongo
import time
from pymongo import MongoClient

print("Connecting to MongoDB...")
client = MongoClient("mongodb://localhost:27017")
db = client["kozmetik"] 
collection = db["ingredients"]

translation_dict = {
    "antioksidan": "Antioxidant",
    "kıvamlaştırıcı": "Thickening Agent",
    "koruyucu": "Preservative",
    "çözücü": "Solvent",
    "koku": "Fragrance",
    "nemlendirici": "Moisturizer",
    "yumuşatıcı": "Emollient",
    "emülgatör": "Emulsifier",
    "yüzey aktif madde": "Surfactant",
    "parfüm": "Perfume",
    "cilt yenileyici": "Skin Replenishing",
    "yatıştırıcı": "Soothing",
    "güneş koruyucu": "Sunscreen",
    "aşındırıcı": "Abrasive",
    "emici": "Absorbent",
    "bağlayıcı": "Binding",
    "tamponlama": "Buffering",
    "temizleyici": "Cleansing",
    "film oluşturucu": "Film Forming",
    "köpürtücü": "Foaming",
    "jel oluşturucu": "Gel Forming",
    "nem tutucu": "Humectant",
    "ph ayarlayıcı": "pH Adjuster",
    "cilt şartlandırıcı": "Skin Conditioning",
    "hacim arttırıcı": "Bulking",
    "büzücü": "Astringent",
    "maskeleme": "Masking",
    "antimikrobiyal": "Antimicrobial",
    "deodorant": "Deodorant",
    "kepek önleyici": "Antidandruff",
    "renk verici": "Colorant",
    "saç şartlandırıcı": "Hair Conditioning",
    "antistatik": "Antistatic"
}

def translate_function(func):
    if not func: return func
    lower_f = func.lower()
    for tr_k, en_v in translation_dict.items():
        if tr_k in lower_f:
            return en_v
    return func

ingredients = collection.find({"functions": {"$exists": True, "$ne": []}})

updates = []
count = 0

for ing in ingredients:
    functions = ing.get("functions", [])
    functions_en = []
    
    for f in functions:
        functions_en.append(translate_function(f))
        
    updates.append(pymongo.UpdateOne(
        {"_id": ing["_id"]},
        {"$set": {"functions_en": functions_en}}
    ))
    
    count += 1
    if len(updates) >= 1000:
        collection.bulk_write(updates)
        print(f"Updated {count} records...")
        updates = []

if updates:
    collection.bulk_write(updates)
    print(f"Updated {count} records...")

print("Translation completed successfully!")
