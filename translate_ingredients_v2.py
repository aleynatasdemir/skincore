import pymongo
from pymongo import MongoClient

print("Connecting to MongoDB...")
client = MongoClient("mongodb://localhost:27017")
db = client["kozmetik"] 
collection = db["ingredients"]

translation_dict = {
    # Original
    "antioksidan": "Antioxidant",
    "kıvamlaştırıcı": "Thickening Agent",
    "kıvam arttırıcı": "Thickening Agent",
    "kıvam artırıcı": "Thickening Agent",
    "kıvam düzenleyici": "Viscosity Modifier",
    "koruyucu": "Preservative",
    "çözücü": "Solvent",
    "koku": "Fragrance",
    "nemlendirici": "Moisturizer",
    "yumuşatıcı": "Emollient",
    "emolyan": "Emollient",
    "emülgatör": "Emulsifier",
    "yüzey aktif madde": "Surfactant",
    "yüzey aktif": "Surfactant",
    "sürfaktan": "Surfactant",
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
    "ph düzenleyici": "pH Adjuster",
    "cilt şartlandırıcı": "Skin Conditioning",
    "hacim arttırıcı": "Bulking",
    "büzücü": "Astringent",
    "maskeleme": "Masking",
    "antimikrobiyal": "Antimicrobial",
    "deodorant": "Deodorant",
    "kepek önleyici": "Antidandruff",
    "renk verici": "Colorant",
    "saç şartlandırıcı": "Hair Conditioning",
    "antistatik": "Antistatic",
    
    # New additions from DB analysis
    "akne karşıtı": "Anti-Acne",
    "aksesuar": "Accessory",
    "aktif bileşen": "Active Ingredient",
    "aktif madde": "Active Ingredient",
    "aktif içerik": "Active Ingredient",
    "alet": "Tool",
    "ambalaj malzemesi": "Packaging Material",
    "ambalaj materyali": "Packaging Material",
    "anti-aging": "Anti-Aging",
    "yaşlanma karşıtı": "Anti-Aging",
    "anti-enflamatuar": "Anti-Inflammatory",
    "anti-inflamatuar": "Anti-Inflammatory",
    "antibakteriyel": "Antibacterial",
    "antifungal": "Antifungal",
    "antiseptik": "Antiseptic",
    "aplikatör": "Applicator",
    "aplikatör malzemesi": "Applicator Material",
    "aydınlatıcı": "Brightening",
    "cilt aydınlatıcı": "Skin Brightening",
    "cildin parlaklaştırılması": "Skin Brightening",
    "cilt parlaklaştırıcı": "Skin Brightening",
    "cilt beyazlatıcı": "Skin Whitening",
    "ağız bakım ajanı": "Oral Care Agent",
    "bakım": "Care",
    "bakım ajanı": "Care Agent",
    "bakım maddesi": "Care Agent",
    "bariyer onarıcı": "Barrier Repair",
    "cilt bariyeri onarıcı": "Skin Barrier Repair",
    "cilt bariyeri destekleyici": "Skin Barrier Supporting",
    "cilt bariyeri desteği": "Skin Barrier Support",
    "besleyici": "Nourishing",
    "bilinmiyor": "Unknown",
    "boya": "Dye / Colorant",
    "bronzlaştırıcı": "Bronzing",
    "canlandırıcı": "Revitalizing",
    "cilt bakım ajanı": "Skin Care Agent",
    "cilt bakım maddesi": "Skin Care Agent",
    "cilt bakımı": "Skin Care",
    "cilt dengeleyici": "Skin Balancing",
    "cilt düzenleyici": "Skin Conditioning Agent",
    "cilt kondisyonlayıcı": "Skin Conditioning Agent",
    "cilt onarıcı": "Skin Repairing",
    "ciltle aynı içerik": "Skin-Identical Ingredient",
    "daralan gözenekler": "Pore Minimizing",
    "gözenek sıkılaştırıcı": "Pore Tightening",
    "dengeleyici": "Balancing",
    "destekleyici": "Supporting",
    "doku arttırıcı": "Texture Enhancer",
    "doku düzenleyici": "Texture Modifier",
    "doku geliştirici": "Texture Improver",
    "doku oluşturucu": "Texture Forming",
    "doku verici": "Texturizing",
    "eksfoliyan": "Exfoliant",
    "eksfoliyant": "Exfoliant",
    "peeling": "Peeling / Exfoliant",
    "emülsiyon sabitleyici": "Emulsion Stabilizer",
    "emülsiyon stabilizatörü": "Emulsion Stabilizer",
    "endokrin bozucular": "Endocrine Disruptors",
    "etik standart": "Ethical Standard",
    "ferahlatıcı": "Refreshing",
    "güneş filtresi": "UV Filter",
    "uv filtresi": "UV Filter",
    "uv filtresi destekleyici": "UV Filter Booster",
    "güvenli içerik": "Safe Ingredient",
    "güvenlik": "Safety",
    "güçlendirici": "Strengthening",
    "hacim verici": "Volumizing",
    "hafifletici": "Soothing",
    "hücre yenileyici": "Cell Renewing",
    "hücre iletişimi": "Cell-Communicating",
    "hücreler ile etkileşim": "Cell-Communicating",
    "ısıtıcı ajan": "Warming Agent",
    "ışık stabilizatörü": "Light Stabilizer",
    "ışıltı verici": "Illuminating",
    "jelleştirici": "Gelling Agent",
    "kalıcı makyaj": "Permanent Makeup",
    "kalıcılaştırıcı": "Long Lasting Agent",
    "kalıcılık artırıcı": "Long Lasting Agent",
    "kapatıcı": "Concealing",
    "kaplama": "Coating",
    "kaydırıcı": "Slip Agent",
    "kayganlaştırıcı": "Lubricant",
    "keratolitik": "Keratolytic",
    "kondisyoner": "Conditioner",
    "kondisyonlayıcı": "Conditioning",
    "koyulaştırıcı": "Thickener",
    "kozmetik": "Cosmetic",
    "köpük arttırıcı": "Foam Booster",
    "makyaj": "Makeup",
    "materyal": "Material",
    "matlaştırıcı": "Mattifying",
    "mikrobiyom dengeleyici": "Microbiome Balancing",
    "mineral": "Mineral",
    "oksijen taşıyıcı": "Oxygen Carrier",
    "onarıcı": "Repairing",
    "opaklaştırıcı": "Opacifying",
    "optik düzenleyici": "Optical Modifier",
    "parlatıcı": "Glossing",
    "pazarlama ifadesi": "Marketing Claim",
    "plastikleştirici": "Plasticizer",
    "probiyotik": "Probiotic",
    "pürüzsüzleştirici": "Smoothing",
    "renklendirici": "Colorant",
    "sabitleyici": "Fixative",
    "sakinleştirici": "Calming",
    "saç bakım ajanı": "Hair Care Agent",
    "saç bakımı": "Hair Care",
    "sebum dengeleyici": "Sebum Balancing",
    "serinletici": "Cooling",
    "stabilizatör": "Stabilizer",
    "suya dayanıklı": "Water Resistant",
    "suya dayanıklılaştırıcı": "Water Resistance Enhancer",
    "sürdürülebilirlik": "Sustainability",
    "sıkılaştırıcı": "Firming",
    "tatlandırıcı": "Flavoring / Sweetener",
    "taşıyıcı": "Carrier",
    "taşıyıcı sistem": "Carrier System",
    "tonik": "Tonic",
    "topaklanma önleyici": "Anticaking",
    "tüy dökücü": "Depilatory",
    "uygulama aracı": "Application Tool",
    "viskozite artırıcı": "Viscosity Increasing Agent",
    "viskozite kontrolü": "Viscosity Controlling",
    "viskozite regülatörü": "Viscosity Controlling",
    "yapılandırıcı": "Restructuring",
    "yapısal materyal": "Structural Material",
    "yapıştırıcı": "Adhesive",
    "yara iyileştirici": "Wound Healing",
    "yenileyici": "Renewing",
    "yüzey işleyici": "Surface Modifier",
    "çözündürücü": "Solubilizer",
    "ödem giderici": "Anti-Edema",
    "itici gaz": "Propellant",
    "şekillendirici": "Styling",
    "şelatlama maddesi": "Chelating Agent",
    "şelatlama ajanı": "Chelating Agent",
    "şelatlar": "Chelating",
    "şelatlayıcı": "Chelating"
}

def translate_function(func):
    if not func: return func
    lower_f = func.lower()
    
    # First exact match
    if lower_f in translation_dict:
        return translation_dict[lower_f]
        
    # Then partial match
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
        updates = []

if updates:
    collection.bulk_write(updates)

print(f"Total Translation completed successfully for {count} records!")
