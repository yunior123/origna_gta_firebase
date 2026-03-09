Verify that ALL schema layers are in perfect sync.

Read these files in order:
1. docs/database_schema.json (source of truth)
2. functions/schema_constants.py (Python mirror)
3. origna_gta/lib/core/schema/schema_constants.dart (Dart mirror)
4. functions/models/base.py, order.py, product.py, user.py (Python models)
5. origna_gta/lib/models/generated/base_models.dart, order_models.dart, product_models.dart, user_models.dart (Dart models)
6. firestore.rules (security rules field names)

For each collection in the schema:
- Verify every field exists in BOTH constants files
- Verify every enum value exists in BOTH Python and Dart
- Verify Pydantic fields match Freezed fields (name, type, required/optional)
- Verify firestore.rules references correct field names

Output as a table showing sync status per field. Flag any DRIFT.
Use ultrathink for thorough analysis.
