from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017/')
products = client['kozmetik']['products']
items = list(products.find({"barcode": "8690644147234"}))
print("Found items count:", len(items))
for i, item in enumerate(items):
    print(f"Item {i+1} ID:", item["_id"])
    if "embedding" in item and item["embedding"]:
        print(f"Item {i+1} HAS embedding! Length: {len(item['embedding'])}")
    else:
        print(f"Item {i+1} NO embedding.")
