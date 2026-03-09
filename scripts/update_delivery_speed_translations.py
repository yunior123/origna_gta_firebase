import json

delivery_speeds = {
    'standard': {
        'en': {'name': 'Free Delivery', 'time': '3-5 business days'},
        'fr': {'name': 'Livraison gratuite', 'time': '3-5 jours ouvrables'}
    },
    'express': {
        'en': {'name': 'Express', 'time': '1-2 business days'},
        'fr': {'name': 'Express', 'time': '1-2 jours ouvrables'}
    },
    'same_day': {
        'en': {'name': 'Same Day', 'time': 'Delivered today'},
        'fr': {'name': 'Le jour même', 'time': 'Livré aujourd\'hui'}
    },
    'international': {
        'en': {'name': 'International Standard', 'time': '15-30 business days'},
        'fr': {'name': 'Standard international', 'time': '15-30 jours ouvrables'}
    },
    'international_express': {
        'en': {'name': 'International Express', 'time': '7-15 business days'},
        'fr': {'name': 'Express international', 'time': '7-15 jours ouvrables'}
    }
}

def update_json(file_path, lang):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    if 'checkout' not in data:
        data['checkout'] = {}
    
    data['checkout']['delivery_speed'] = {k: v[lang] for k, v in delivery_speeds.items()}
    
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=4)

if __name__ == "__main__":
    update_json('origna_gta/assets/translations/en.json', 'en')
    update_json('origna_gta/assets/translations/fr.json', 'fr')
    print("Successfully updated en.json and fr.json with all delivery speed translations.")
