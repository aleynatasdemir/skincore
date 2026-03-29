import os
import json
from flask import Flask, jsonify, request, send_from_directory, render_template

app = Flask(__name__, static_folder='static', template_folder='templates')

BASE_PATH = "/Users/aleyna/Desktop/matching_embedding"
MATCHED_FILE = os.path.join(BASE_PATH, "matched_loreal_products.json")
CORRECT_FILE = os.path.join(BASE_PATH, "correct_matches.json")
INCORRECT_FILE = os.path.join(BASE_PATH, "incorrect_matches.json")

def load_json(filepath, default_val=None):
    if default_val is None:
        default_val = []
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            try:
                return json.load(f)
            except:
                return default_val
    return default_val

def save_json(filepath, data):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def get_id(item):
    local_p = item.get('local_product') or ""
    ewg_p = item.get('ewg_product') or ""
    local_img = item.get('local_image') or ""
    ewg_img = item.get('ewg_image') or ""
    score = item.get('score', 0)
    # Aynı isme ve farklı skora (veya resme) sahip ürünlerin
    # benzersiz idler almasını sağlıyoruz
    return f"{local_p}||{ewg_p}||{local_img.lstrip('/')}||{ewg_img.lstrip('/')}||{score}"

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/essence_wats_img/<path:filename>')
def serve_wats_image(filename):
    return send_from_directory(BASE_PATH, f"essence_wats_img/{filename}")

@app.route('/essence_ewg_img/<path:filename>')
def serve_ewg_image(filename):
    return send_from_directory(BASE_PATH, f"essence_ewg_img/{filename}")

@app.route('/loreal_ewg_img/<path:filename>')
def serve_loreal_ewg_image(filename):
    return send_from_directory(BASE_PATH, f"loreal/loreal_ewg_img/{filename}")

@app.route('/loreal_local_img/<path:filename>')
def serve_loreal_local_image(filename):
    return send_from_directory(BASE_PATH, f"loreal/loreal_local_img/{filename}")

def extract_from_nested(item_dict):
    text = ""
    image = None
    if isinstance(item_dict, dict):
        for part in item_dict.get('content', []):
            if 'text' in part and not text:
                text = part['text']
            if 'image' in part and not image:
                image = part['image']
    return text, image

@app.route('/api/next_match', methods=['GET'])
def get_next_match():
    matches = load_json(MATCHED_FILE)[:20] # Sadece 20 ürün (göstermelik)
    correct_matches = load_json(CORRECT_FILE)
    incorrect_matches = load_json(INCORRECT_FILE)
    
    decided_locals = {m.get('local_product') for m in correct_matches + incorrect_matches if m.get('local_product')}
    
    remaining_count = sum(1 for m in matches if m.get('local_product') not in decided_locals)

    for match in matches:
        local_text = match.get('local_product', '')
        local_image = match.get('local_image')
        ewg_text = match.get('ewg_product', '')
        ewg_image = match.get('ewg_image')

        if local_text not in decided_locals:
            res = {
                "local_product": local_text,
                "local_image": local_image,
                "ewg_product": ewg_text,
                "ewg_image": ewg_image,
                "score": match.get('text_score', 0) / 100.0
            }
            if isinstance(res.get('local_image'), str) and not res['local_image'].startswith('/') and not res['local_image'].startswith('http'):
                res['local_image'] = '/' + res['local_image']
            if isinstance(res.get('ewg_image'), str) and not res['ewg_image'].startswith('/') and not res['ewg_image'].startswith('http'):
                res['ewg_image'] = '/' + res['ewg_image']
                
            return jsonify({
                "status": "success", 
                "match": res, 
                "remaining": remaining_count
            })
            
    return jsonify({"status": "done", "message": "All matches have been verified!"})

@app.route('/api/submit_decision', methods=['POST'])
def submit_decision():
    data = request.json
    match_data = data.get('match')
    decision = data.get('decision') # "correct" or "incorrect"
    
    if not match_data or not decision:
        return jsonify({"status": "error", "message": "Missing data"}), 400
        
    local_p = match_data.get('local_product')
    
    if decision == "correct":
        correct_matches = load_json(CORRECT_FILE)
        # Avoid duplicates
        if not any(m.get('local_product') == local_p for m in correct_matches):
            correct_matches.append(match_data)
            save_json(CORRECT_FILE, correct_matches)
    elif decision == "incorrect":
        incorrect_matches = load_json(INCORRECT_FILE)
        if not any(m.get('local_product') == local_p for m in incorrect_matches):
            incorrect_matches.append(match_data)
            save_json(INCORRECT_FILE, incorrect_matches)
            
    return jsonify({"status": "success"})

if __name__ == '__main__':
    # Ensure empty files exist
    if not os.path.exists(CORRECT_FILE): save_json(CORRECT_FILE, [])
    if not os.path.exists(INCORRECT_FILE): save_json(INCORRECT_FILE, [])
    
    print("UI Sunucusu başlatılıyor: http://127.0.0.1:5005")
    app.run(port=5005, debug=True)
