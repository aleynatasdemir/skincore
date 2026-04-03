from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017/')
db = client['kozmetik']
products = db['products']
print("Product counts:", products.count_documents({}))

barcode = '8690644147234'
p = products.find_one({"barcode": barcode})
if p:
    print("Found! ID:", p.get("_id"))
    print("Has embedding?", "embedding" in p, p.get("embedding") is not None)
    if "embedding" in p and p["embedding"]:
        print("Embedding length:", len(p["embedding"]))
else:
    print("By string not found")

p2 = products.find_one({"barcode": 8690644147234})
if p2:
    print("Found by int!")
