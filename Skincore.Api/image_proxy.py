#!/usr/bin/env python3
"""
Görsel URL'sini curl_cffi ile indirir, JPEG'e çevirip base64'e yazarak stdout'a gönderir.
Kullanım: python3 image_proxy.py <url>
"""
import sys
import subprocess

def ensure_deps():
    for pkg in ("curl_cffi", "Pillow"):
        try:
            __import__("curl_cffi" if pkg == "curl_cffi" else "PIL")
        except ImportError:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pkg, "--quiet"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

ensure_deps()

import base64
from io import BytesIO
from PIL import Image
from curl_cffi import requests

MAX_SIDE = 512   # embed_images.py ile aynı

def get_headers(url: str) -> dict:
    headers = {
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    }
    if "watsons.com.tr" in url:
        headers["Referer"] = "https://www.watsons.com.tr/"
        headers["Origin"]  = "https://www.watsons.com.tr"
    elif "sephora" in url:
        headers["Referer"] = "https://www.sephora.com.tr/"
        headers["Origin"]  = "https://www.sephora.com.tr"
    elif "gratis.com" in url:
        headers["Referer"] = "https://www.gratis.com/"
    elif "goldenrose" in url:
        headers["Referer"] = "https://shop.goldenrose.com.tr/"
    elif "nivea" in url:
        headers["Referer"] = "https://www.nivea.com.tr/"
    elif "dermokozmetika" in url:
        headers["Referer"] = "https://www.dermokozmetika.com.tr/"
    return headers

def to_jpeg_base64(raw_bytes: bytes) -> str:
    """Her formattan (AVIF dahil) JPEG'e çevir, küçült, base64 döndür."""
    with Image.open(BytesIO(raw_bytes)) as img:
        img = img.convert("RGB")
        img.thumbnail((MAX_SIDE, MAX_SIDE))
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=85)
        return base64.b64encode(buf.getvalue()).decode("utf-8")

def main():
    if len(sys.argv) < 2:
        print("ERROR: url argument required", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    try:
        resp = requests.get(
            url,
            impersonate="chrome110",
            timeout=15,
            headers=get_headers(url),
        )
        resp.raise_for_status()
        if len(resp.content) < 1000:
            print(f"ERROR: too small ({len(resp.content)} bytes)", file=sys.stderr)
            sys.exit(1)
        print(to_jpeg_base64(resp.content), end="")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
