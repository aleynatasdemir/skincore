#!/usr/bin/env python3
"""
bulk_embed.py
1. image_urls boş olan ürünler için ortak_urunler.json'dan barcode eşleştirip image_url günceller.
2. Embedding'i olmayan tüm ürünler için image_proxy.py ile fotoğraf indirip Gemini embedding kaydeder.

Kullanım:
    python3 bulk_embed.py [--dry-run] [--skip-image-update] [--skip-embed]

Gereksinimler:
    pip3 install pymongo requests curl_cffi Pillow
"""

import sys
import os
import json
import time
import base64
import subprocess
import requests
from pymongo import MongoClient
from bson import ObjectId

# ── Ayarlar ──────────────────────────────────────────────────────────────────
MONGO_URI      = "mongodb://localhost:27017/"
DB_NAME        = "kozmetik"
GOOGLE_API_KEY = "AIzaSyBoFPW5SV4fTsThzia704j9_JGW3HK1wSs"
GEMINI_MODEL   = "gemini-embedding-2-preview"
PROXY_SCRIPT   = os.path.join(os.path.dirname(__file__), "image_proxy.py")
BARCODE_MAP_PATH = os.path.join(os.path.dirname(__file__), "ortak_urunler.json")
RATE_LIMIT_SLEEP = 1.0   # saniye — Gemini rate limit için istekler arası bekleme
# ─────────────────────────────────────────────────────────────────────────────

dry_run       = "--dry-run"          in sys.argv
skip_img_upd  = "--skip-image-update" in sys.argv
skip_embed    = "--skip-embed"       in sys.argv

client = MongoClient(MONGO_URI)
col    = client[DB_NAME]["products"]

# ── 1. ortak_urunler.json'dan barcode → image map ────────────────────────────
print("ortak_urunler.json yükleniyor...")
with open(BARCODE_MAP_PATH, encoding="utf-8") as f:
    raw = json.load(f)

barcode_map = {}
for entry in raw:
    img = (entry.get("image") or "").strip()
    if not img:
        continue
    for bc in str(entry.get("barcode", "")).split(","):
        bc = bc.strip()
        if bc:
            barcode_map[bc] = img

print(f"  {len(barcode_map)} barcode → image eşleşmesi yüklendi.")

# ── 2. Fotoğrafsız ürünlerin image_url'sini güncelle ─────────────────────────
if not skip_img_upd:
    print("\n[ADIM 1] Fotoğrafsız ürünler taranıyor...")

    no_image_cursor = col.find(
        {"$or": [
            {"image_urls": {"$exists": False}},
            {"image_urls": {"$size": 0}},
            {"image_urls": {"$elemMatch": {"fileUrl": {"$in": ["", None]}}}}
        ]},
        {"_id": 1, "barcode": 1, "name": 1, "image_urls": 1}
    )

    updated = 0
    skipped = 0
    for doc in no_image_cursor:
        barcode = str(doc.get("barcode", "")).strip()
        img_url = barcode_map.get(barcode)
        if not img_url:
            skipped += 1
            continue

        print(f"  Güncelleniyor: {barcode} — {doc.get('name','?')[:50]}")
        if not dry_run:
            col.update_one(
                {"_id": doc["_id"]},
                {"$set": {"image_urls": [{"fileUrl": img_url, "fileName": ""}]}}
            )
        updated += 1

    print(f"  Güncellenen: {updated}, eşleşme bulunamayan: {skipped}")

# ── Helper: image_proxy.py ile base64 al ─────────────────────────────────────
def fetch_image_base64(url: str) -> str | None:
    try:
        result = subprocess.run(
            ["python3", PROXY_SCRIPT, url],
            capture_output=True, text=True, timeout=30
        )
        out = result.stdout.strip()
        if out and len(out) > 100:
            return out
        return None
    except Exception as e:
        print(f"    image_proxy hatası: {e}")
        return None

# ── Helper: Gemini embedding ─────────────────────────────────────────────────
def gemini_embed(image_base64: str) -> list[float] | None:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:embedContent?key={GOOGLE_API_KEY}"
    payload = {
        "model": f"models/{GEMINI_MODEL}",
        "content": {
            "parts": [{"inline_data": {"mime_type": "image/jpeg", "data": image_base64}}]
        }
    }
    try:
        res = requests.post(url, json=payload, timeout=30)
        if res.status_code == 200:
            return res.json()["embedding"]["values"]
        else:
            print(f"    Gemini hata {res.status_code}: {res.text[:200]}")
            return None
    except Exception as e:
        print(f"    Gemini istek hatası: {e}")
        return None

# ── 3. Embedding'i olmayan ürünleri embedd et ─────────────────────────────────
if not skip_embed:
    print("\n[ADIM 2] Embedding'i olmayan ürünler taranıyor...")

    no_embed_cursor = col.find(
        {"$or": [
            {"embedding": {"$exists": False}},
            {"embedding": {"$size": 0}}
        ]},
        {"_id": 1, "barcode": 1, "name": 1, "image_urls": 1}
    )

    total = col.count_documents({"$or": [
        {"embedding": {"$exists": False}},
        {"embedding": {"$size": 0}}
    ]})
    print(f"  Toplam embedding'siz ürün: {total}")

    done = 0
    failed = 0

    for doc in no_embed_cursor:
        product_id = str(doc["_id"])
        barcode    = str(doc.get("barcode", "")).strip()
        name       = doc.get("name", "?")[:50]

        # image_url bul
        img_urls = doc.get("image_urls", [])
        image_url = ""
        if isinstance(img_urls, list) and img_urls:
            first = img_urls[0]
            if isinstance(first, dict):
                image_url = first.get("fileUrl", "") or first.get("fileName", "")
            elif isinstance(first, str):
                image_url = first

        # URL yoksa barcode_map'ten dene
        if not image_url and barcode:
            image_url = barcode_map.get(barcode, "")

        if not image_url:
            print(f"  [{done+failed+1}/{total}] SKIP (fotoğraf yok): {barcode} — {name}")
            failed += 1
            continue

        print(f"  [{done+failed+1}/{total}] İşleniyor: {barcode} — {name}")

        if dry_run:
            done += 1
            continue

        # Fotoğraf indir
        b64 = fetch_image_base64(image_url)
        if not b64:
            print(f"    SKIP: fotoğraf indirilemedi")
            failed += 1
            time.sleep(0.2)
            continue

        # Gemini embedding
        embedding = gemini_embed(b64)
        if not embedding:
            print(f"    SKIP: embedding alınamadı")
            failed += 1
            time.sleep(1)
            continue

        # MongoDB kaydet
        col.update_one(
            {"_id": doc["_id"]},
            {"$set": {"embedding": embedding, "has_embedding": True}}
        )
        done += 1
        print(f"    OK — {len(embedding)} boyut")
        time.sleep(RATE_LIMIT_SLEEP)

    print(f"\n  Başarılı: {done}, Başarısız/Atlanan: {failed}")

client.close()
print("\nTamamlandı.")
