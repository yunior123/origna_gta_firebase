"""Module patch_translations.py."""
import json

files = ['origna_gta/assets/translations/en.json', 'origna_gta/assets/translations/fr.json']

for file in files:
    with open(file, 'r') as f:
        data = json.load(f)
    
    if 'errors' not in data:
        data['errors'] = {}
        
    if 'generic_error' not in data['errors']:
        data['errors']['generic_error'] = "An unexpected error occurred. Please try again." if 'en' in file else "Une erreur inattendue s'est produite. Veuillez réessayer."
        
    if 'service_unavailable' not in data['errors']:
        data['errors']['service_unavailable'] = "Service is temporarily unavailable. Please try again later." if 'en' in file else "Le service est temporairement indisponible. Veuillez réessayer plus tard."
        
    with open(file, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
