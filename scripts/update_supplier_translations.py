import json

suppliers = {
    'aliexpress': {
        'en': {'display_name': 'AliExpress', 'region': 'Asia', 'country': 'China', 'description': 'Global retail marketplace'},
        'fr': {'display_name': 'AliExpress', 'region': 'Asie', 'country': 'Chine', 'description': 'Marché de détail mondial'}
    },
    'alibaba': {
        'en': {'display_name': 'Alibaba', 'region': 'Asia', 'country': 'China', 'description': 'B2B wholesale marketplace'},
        'fr': {'display_name': 'Alibaba', 'region': 'Asie', 'country': 'Chine', 'description': 'Marché de gros B2B'}
    },
    '1688': {
        'en': {'display_name': '1688', 'region': 'Asia', 'country': 'China', 'description': 'Chinese domestic B2B platform'},
        'fr': {'display_name': '1688', 'region': 'Asie', 'country': 'Chine', 'description': 'Plateforme B2B domestique chinoise'}
    },
    'dhgate': {
        'en': {'display_name': 'DHgate', 'region': 'Asia', 'country': 'China', 'description': 'Cross-border e-commerce platform'},
        'fr': {'display_name': 'DHgate', 'region': 'Asie', 'country': 'Chine', 'description': 'Plateforme de commerce électronique transfrontalier'}
    },
    'temu': {
        'en': {'display_name': 'Temu', 'region': 'Asia', 'country': 'China', 'description': 'Fast shipping marketplace'},
        'fr': {'display_name': 'Temu', 'region': 'Asie', 'country': 'Chine', 'description': 'Marché à expédition rapide'}
    },
    'made_in_china': {
        'en': {'display_name': 'Made-in-China', 'region': 'Asia', 'country': 'China', 'description': 'B2B sourcing platform'},
        'fr': {'display_name': 'Made-in-China', 'region': 'Asie', 'country': 'Chine', 'description': 'Plateforme de sourcing B2B'}
    },
    'global_sources': {
        'en': {'display_name': 'Global Sources', 'region': 'Asia', 'country': 'China/Hong Kong', 'description': 'Asia-based B2B platform'},
        'fr': {'display_name': 'Global Sources', 'region': 'Asie', 'country': 'Chine/Hong Kong', 'description': 'Plateforme B2B basée en Asie'}
    },
    'cjdropshipping': {
        'en': {'display_name': 'CJ Dropshipping', 'region': 'Global', 'country': 'China (warehouses worldwide)', 'description': 'Dropshipping & fulfillment service'},
        'fr': {'display_name': 'CJ Dropshipping', 'region': 'Global', 'country': 'Chine (entrepôts mondiaux)', 'description': 'Service de dropshipping et de traitement'}
    },
    'spocket': {
        'en': {'display_name': 'Spocket', 'region': 'US/EU', 'country': 'USA/Europe', 'description': 'US/EU dropshipping suppliers'},
        'fr': {'display_name': 'Spocket', 'region': 'US/UE', 'country': 'États-Unis/Europe', 'description': 'Fournisseurs de dropshipping US/UE'}
    },
    'printful': {
        'en': {'display_name': 'Printful', 'region': 'Global', 'country': 'USA/EU/Mexico', 'description': 'Print-on-demand fulfillment'},
        'fr': {'display_name': 'Printful', 'region': 'Global', 'country': 'États-Unis/UE/Mexique', 'description': 'Exécution d\'impression à la demande'}
    },
    'printify': {
        'en': {'display_name': 'Printify', 'region': 'Global', 'country': 'Various', 'description': 'Print-on-demand platform'},
        'fr': {'display_name': 'Printify', 'region': 'Global', 'country': 'Divers', 'description': 'Plateforme d\'impression à la demande'}
    },
    'gmarket': {
        'en': {'display_name': 'Gmarket', 'region': 'Asia', 'country': 'South Korea', 'description': 'Korean e-commerce platform'},
        'fr': {'display_name': 'Gmarket', 'region': 'Asie', 'country': 'Corée du Sud', 'description': 'Plateforme de commerce électronique coréenne'}
    },
    'coupang': {
        'en': {'display_name': 'Coupang', 'region': 'Asia', 'country': 'South Korea', 'description': 'Korean rocket delivery'},
        'fr': {'display_name': 'Coupang', 'region': 'Asie', 'country': 'Corée du Sud', 'description': 'Livraison rocket coréenne'}
    },
    'rakuten': {
        'en': {'display_name': 'Rakuten', 'region': 'Asia', 'country': 'Japan', 'description': 'Japanese e-commerce giant'},
        'fr': {'display_name': 'Rakuten', 'region': 'Asie', 'country': 'Japon', 'description': 'Géant japonais du commerce électronique'}
    },
    'amazon_japan': {
        'en': {'display_name': 'Amazon Japan', 'region': 'Asia', 'country': 'Japan', 'description': 'Amazon Japan marketplace'},
        'fr': {'display_name': 'Amazon Japan', 'region': 'Asie', 'country': 'Japon', 'description': 'Marché Amazon Japon'}
    },
    'indiamart': {
        'en': {'display_name': 'IndiaMart', 'region': 'Asia', 'country': 'India', 'description': 'Indian B2B marketplace'},
        'fr': {'display_name': 'IndiaMart', 'region': 'Asie', 'country': 'Inde', 'description': 'Marché B2B indien'}
    },
    'tradeindia': {
        'en': {'display_name': 'TradeIndia', 'region': 'Asia', 'country': 'India', 'description': 'Indian B2B platform'},
        'fr': {'display_name': 'TradeIndia', 'region': 'Asie', 'country': 'Inde', 'description': 'Plateforme B2B indienne'}
    },
    'faire': {
        'en': {'display_name': 'Faire', 'region': 'US/EU', 'country': 'USA/Europe', 'description': 'Wholesale marketplace'},
        'fr': {'display_name': 'Faire', 'region': 'US/UE', 'country': 'États-Unis/Europe', 'description': 'Marché de gros'}
    },
    'amazon_europe': {
        'en': {'display_name': 'Amazon Europe', 'region': 'Europe', 'country': 'Germany/UK/France', 'description': 'Amazon European marketplaces'},
        'fr': {'display_name': 'Amazon Europe', 'region': 'Europe', 'country': 'Allemagne/RU/France', 'description': 'Marchés européens Amazon'}
    },
    'amazon_usa': {
        'en': {'display_name': 'Amazon USA', 'region': 'North America', 'country': 'USA', 'description': 'Amazon US marketplace'},
        'fr': {'display_name': 'Amazon USA', 'region': 'Amérique du Nord', 'country': 'États-Unis', 'description': 'Marché Amazon US'}
    },
    'walmart': {
        'en': {'display_name': 'Walmart', 'region': 'North America', 'country': 'USA', 'description': 'US retail giant'},
        'fr': {'display_name': 'Walmart', 'region': 'Amérique du Nord', 'country': 'États-Unis', 'description': 'Géant de la vente au détail aux États-Unis'}
    },
    'costco': {
        'en': {'display_name': 'Costco Business', 'region': 'North America', 'country': 'USA/Canada', 'description': 'Wholesale club'},
        'fr': {'display_name': 'Costco Business', 'region': 'Amérique du Nord', 'country': 'États-Unis/Canada', 'description': 'Club de vente en gros'}
    },
    'local': {
        'en': {'display_name': 'Local Canadian Supplier', 'region': 'Canada', 'country': 'Canada', 'description': 'Canadian-based supplier'},
        'fr': {'display_name': 'Fournisseur canadien local', 'region': 'Canada', 'country': 'Canada', 'description': 'Fournisseur basé au Canada'}
    },
    'etsy_wholesale': {
        'en': {'display_name': 'Etsy Wholesale', 'region': 'Global', 'country': 'Various', 'description': 'Handmade & vintage items'},
        'fr': {'display_name': 'Etsy Wholesale', 'region': 'Global', 'country': 'Divers', 'description': 'Articles faits à la main et vintage'}
    },
    'custom': {
        'en': {'display_name': 'Custom Supplier', 'region': 'Custom', 'country': 'Specify', 'description': 'Add your own supplier details'},
        'fr': {'display_name': 'Fournisseur personnalisé', 'region': 'Personnalisé', 'country': 'Préciser', 'description': 'Ajoutez vos propres détails de fournisseur'}
    },
    'other': {
        'en': {'display_name': 'Other', 'region': 'Various', 'country': 'Various', 'description': 'Other supplier not listed'},
        'fr': {'display_name': 'Autre', 'region': 'Divers', 'country': 'Divers', 'description': 'Autre fournisseur non répertorié'}
    }
}

def update_json(file_path, lang):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    data['supplier'] = {k: v[lang] for k, v in suppliers.items()}
    
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    update_json('origna_gta/assets/translations/en.json', 'en')
    update_json('origna_gta/assets/translations/fr.json', 'fr')
    print("Successfully updated en.json and fr.json with supplier translations.")
