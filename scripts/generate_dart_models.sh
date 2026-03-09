#!/bin/bash
#
# Generate Dart models from JSON Schema using Quicktype
# Run: ./scripts/generate_dart_models.sh
#

set -e

echo "🚀 Generating Dart models from JSON Schema..."

# Directories
SCHEMA_DIR="docs/json_schemas/individual"
OUTPUT_DIR="origna_gta/lib/models/generated"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate Dart models using Quicktype
echo "📝 Generating models..."

# Use the combined schema file instead of individual files
COMBINED_SCHEMA="docs/json_schemas/models.json"

quicktype \
  --src-lang schema \
  --lang dart \
  --out "$OUTPUT_DIR/models.dart" \
  --required-props \
  --nullability \
  --density dense \
  "$COMBINED_SCHEMA"

echo "✅ Dart models generated: $OUTPUT_DIR/models.dart"

# Generate individual files for better organization (optional)
# Uncomment if you prefer individual files per model

# for schema_file in "$SCHEMA_DIR"/*.json; do
#   filename=$(basename "$schema_file" .json)
#   echo "  - Generating $filename.dart..."
#   
#   quicktype \
#     --src-lang schema \
#     --lang dart \
#     --out "$OUTPUT_DIR/${filename,,}.dart" \
#     --density dense \
#     --required-props \
#     --no-enums \
#     --null-safety \
#     --use-freezed \
#     --use-json-annotation \
#     "$schema_file"
# done

echo ""
echo "🎉 Generation complete!"
echo ""
echo "Next steps:"
echo "1. cd origna_gta"
echo "2. flutter pub get"
echo "3. flutter pub run build_runner build --delete-conflicting-outputs"
echo "4. Import with: import 'package:origna_gta/models/generated/models.dart';"
