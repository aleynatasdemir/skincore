import pymongo
client = pymongo.MongoClient("mongodb://localhost:27017")
collection = client["kozmetik"]["ingredients"]

fix_dict = {
    'Aktif İçerik': 'Active Ingredient',
    'Ciltle Aynı İçerik': 'Skin-Identical Ingredient',
    'Güvenli İçerik': 'Safe Ingredient',
    'Hücre İletişimi': 'Cell-Communicating',
    'Isıtıcı Ajan': 'Warming Agent',
    'Işıltı Verici': 'Illuminating',
    'Işıltı verici': 'Illuminating',
    'Pazarlama İfadesi': 'Marketing Claim',
    'Yara İyileştirici': 'Wound Healing',
    'Yüzey İşleyici': 'Surface Modifier',
    'İtici Gaz': 'Propellant'
}

count = 0
for ing in collection.find({"functions_en": {"$in": list(fix_dict.keys())}}):
    new_funcs = [fix_dict.get(f, f) for f in ing.get("functions_en", [])]
    collection.update_one({"_id": ing["_id"]}, {"$set": {"functions_en": new_funcs}})
    count += 1
print(f"Fixed remaining {count} Turkish characters!")
