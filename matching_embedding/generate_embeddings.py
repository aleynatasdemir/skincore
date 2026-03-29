import os
import json
import base64
import time
import requests
from dotenv import load_dotenv
from PIL import Image
from io import BytesIO

# ----------------
# CONFIG
# ----------------

BASE_PATH = "/Users/aleyna/Desktop/embedding"

INPUT_FILE = f"{BASE_PATH}/loreal_local_products.json"
OUTPUT_FILE = f"{BASE_PATH}/embedded_loreal_local_products.json"

SKIPPED_FILE = f"{BASE_PATH}/skipped_loreal_local_products.json"
FAILED_FILE = f"{BASE_PATH}/api_failed_loreal_local_products.json"

MODEL = "gemini-embedding-2-preview"

REQUEST_DELAY = 0.25
MAX_RETRIES = 3
MAX_IMAGE_MB = 4

# ----------------
# API
# ----------------

load_dotenv()
API_KEY = os.environ.get("GEMINI_API_KEY")

if not API_KEY:
    print("GEMINI_API_KEY bulunamadı")
    exit()

URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:embedContent?key={API_KEY}"

# ----------------
# IMAGE PROCESSING
# ----------------

def process_image(path):

    try:
        with Image.open(path) as img:

            img = img.convert("RGB")
            img.thumbnail((512, 512))

            buffer = BytesIO()
            img.save(buffer, format="JPEG", quality=85)

            data = buffer.getvalue()

            if len(data) > MAX_IMAGE_MB * 1024 * 1024:
                return None, "image_too_large"

            return base64.b64encode(data).decode("utf-8"), None

    except Exception:
        return None, "image_corrupted"

# ----------------
# BUILD PAYLOAD
# ----------------

def build_parts(item):

    text = None
    image_b64 = None
    reason = None

    for part in item.get("content", []):

        if "text" in part:
            text = part["text"]

        if "image" in part:

            img_path = os.path.join(BASE_PATH, part["image"])

            if os.path.exists(img_path):

                image_b64, reason = process_image(img_path)

            else:
                reason = "image_not_found"

    if not text:
        return None, "text_missing"

    parts = [{"text": text}]

    if image_b64:
        parts.append({
            "inlineData": {
                "mimeType": "image/jpeg",
                "data": image_b64
            }
        })

    return parts, reason

# ----------------
# EMBEDDING
# ----------------

def get_embedding(parts):

    payload = {
        "model": f"models/{MODEL}",
        "content": {
            "parts": parts
        }
    }

    for _ in range(MAX_RETRIES):

        try:

            r = requests.post(
                URL,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=60
            )

            if r.status_code == 200:

                data = r.json()

                if "embedding" in data:
                    return data["embedding"]["values"]

                return None

            else:
                time.sleep(1)

        except Exception:
            time.sleep(1)

    return None

# ----------------
# LOAD DATA
# ----------------

with open(INPUT_FILE, "r", encoding="utf-8") as f:
    products = json.load(f)

embedded = []
skipped = []
api_failed = []

print("Toplam ürün:", len(products))

# ----------------
# MAIN LOOP
# ----------------

for i, item in enumerate(products):

    parts, reason = build_parts(item)

    if not parts:

        skipped.append({
            "item": item,
            "reason": reason
        })

        continue

    embedding = get_embedding(parts)

    if embedding:

        item["embedding"] = embedding
        embedded.append(item)

        if len(embedded) % 10 == 0:
            print(f"[{len(embedded)}/{len(products)}] embedding alındı")

    else:

        api_failed.append({
            "item": item,
            "reason": "api_error"
        })

    time.sleep(REQUEST_DELAY)

# ----------------
# SAVE FILES
# ----------------

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(embedded, f, ensure_ascii=False, indent=2)

with open(SKIPPED_FILE, "w", encoding="utf-8") as f:
    json.dump(skipped, f, ensure_ascii=False, indent=2)

with open(FAILED_FILE, "w", encoding="utf-8") as f:
    json.dump(api_failed, f, ensure_ascii=False, indent=2)

print("\nBitti")

print("Başarılı:", len(embedded))
print("Skip:", len(skipped))
print("API hata:", len(api_failed))