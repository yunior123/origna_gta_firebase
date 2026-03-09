#!/bin/bash

# Algolia Setup and Initial Index Script
# Run this once to configure Algolia and index existing products

set -e

echo "🚀 Algolia Setup for OrignaGTA"
echo "================================"

# Check if running from project root
if [ ! -d "functions" ] || [ ! -d "origna_gta" ]; then
  echo "❌ Error: Run this script from the project root directory"
  exit 1
fi

# Check if .env file exists in functions
if [ ! -f "functions/.env" ]; then
  echo "❌ Error: functions/.env file not found"
  echo "Create functions/.env with:"
  echo "  ALGOLIA_APP_ID=your_app_id"
  echo "  ALGOLIA_SEARCH_API_KEY=your_search_key"
  echo "  ALGOLIA_WRITE_API_KEY=your_write_key"
  exit 1
fi

# Source the .env file to get Algolia credentials
source functions/.env

if [ -z "$ALGOLIA_APP_ID" ] || [ -z "$ALGOLIA_WRITE_API_KEY" ]; then
  echo "❌ Error: ALGOLIA_APP_ID and ALGOLIA_WRITE_API_KEY must be set in functions/.env"
  exit 1
fi

echo "✅ Algolia credentials found"

# Check if algoliasearch Python package is installed
echo "📦 Checking Python dependencies..."
cd functions
if ! python3 -c "import algoliasearch" 2>/dev/null; then
  echo "Installing algoliasearch..."
  pip3 install algoliasearch==4.6.1
fi
cd ..

echo "✅ Python dependencies ready"

# Create a Python script to configure and index
echo "⚙️  Configuring Algolia index..."
python3 << 'EOF'
import os
import sys
from algoliasearch.search_client import SearchClient

# Get credentials from environment
app_id = os.environ.get('ALGOLIA_APP_ID')
write_key = os.environ.get('ALGOLIA_WRITE_API_KEY')

if not app_id or not write_key:
    print("❌ Missing Algolia credentials")
    sys.exit(1)

# Initialize client
client = SearchClient.create(app_id, write_key)
index = client.init_index('products')

# Configure index settings
print("Setting up index configuration...")
index.set_settings({
    'searchableAttributes': [
        'name',
        'description',
        'searchKeywords',
    ],
    'attributesForFaceting': [
        'categoryId',
        'sellerId',
        'isActive',
        'freeShipping',
        'isPerishable',
    ],
    'customRanking': [
        'desc(rating)',
        'desc(ratingCount)',
        'desc(dateCreated)',
    ],
    'attributesToRetrieve': [
        'objectID',
        'name',
        'description',
        'price',
        'categoryId',
        'sellerId',
        'imageUrls',
        'stockQuantity',
        'rating',
        'ratingCount',
        'isActive',
        'searchKeywords',
        'sellerAddress',
        'weightKg',
        'lengthCm',
        'widthCm',
        'heightCm',
        'isLocalDeliveryOnly',
        'estimatedShipDays',
        'taxCode',
        'deliveryOptions',
        'isPerishable',
        'minimumOrderQuantity',
        'freeShipping',
    ],
    'highlightPreTag': '<mark>',
    'highlightPostTag': '</mark>',
    'hitsPerPage': 20,
})

print("✅ Index configured successfully")

# Test search
try:
    result = index.search('')
    print(f"✅ Search test successful ({result['nbHits']} products indexed)")
except Exception as e:
    print(f"⚠️  Search test failed: {e}")

EOF

echo ""
echo "================================"
echo "✅ Algolia setup complete!"
echo ""
echo "Next steps:"
echo "1. Set Firebase Remote Config keys:"
echo "   - algolia_app_id: $ALGOLIA_APP_ID"
echo "   - algolia_search_api_key: $ALGOLIA_SEARCH_API_KEY"
echo ""
echo "2. Set Google Secret Manager secrets:"
echo "   firebase functions:secrets:set ALGOLIA_APP_ID"
echo "   firebase functions:secrets:set ALGOLIA_WRITE_API_KEY"
echo ""
echo "3. Deploy Cloud Functions:"
echo "   firebase deploy --only functions"
echo ""
echo "4. Existing products will be auto-indexed on next update"
echo "   Or manually trigger indexing via Firestore triggers"
echo ""
echo "5. Test search in the app!"
