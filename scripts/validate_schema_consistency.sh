#!/bin/bash
# Validate schema consistency between Python and Dart models
# Usage: ./scripts/validate_schema_consistency.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Schema Consistency Validation${NC}"
echo -e "${YELLOW}========================================${NC}"

FAILURES=0

# 1. Validate Python Pydantic models
echo -e "\n${YELLOW}[1/4] Validating Python Pydantic models...${NC}"
cd "$REPO_ROOT/functions"
if [ -d "venv" ]; then
    source venv/bin/activate
fi

if python3 -m pytest tests/test_pydantic_models.py -v; then
    echo -e "${GREEN}✓ Python models validated${NC}"
else
    echo -e "${RED}✗ Python model validation failed${NC}"
    FAILURES=$((FAILURES + 1))
fi

# 2. Validate Python schema contract tests
echo -e "\n${YELLOW}[2/4] Validating Python schema contract tests...${NC}"
cd "$REPO_ROOT/functions"
if python3 -m pytest tests/test_schema_consistency.py tests/test_schema_contract.py -q; then
    echo -e "${GREEN}✓ Python schema contract validated${NC}"
else
    echo -e "${RED}✗ Python schema contract validation failed${NC}"
    FAILURES=$((FAILURES + 1))
fi

# 3. Validate Flutter Freezed models
echo -e "\n${YELLOW}[3/4] Validating Flutter Freezed models...${NC}"
cd "$REPO_ROOT/origna_gta"
if flutter test test/unit/schema_models_test.dart; then
    echo -e "${GREEN}✓ Flutter models validated${NC}"
else
    echo -e "${RED}✗ Flutter model validation failed${NC}"
    FAILURES=$((FAILURES + 1))
fi

# 4. Check generated code is up to date
echo -e "\n${YELLOW}[4/4] Checking Freezed code generation...${NC}"
cd "$REPO_ROOT/origna_gta"
# Save current git status
BEFORE=$(git status --porcelain lib/models/generated/)
# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs > /dev/null 2>&1
AFTER=$(git status --porcelain lib/models/generated/)

if [ "$BEFORE" != "$AFTER" ]; then
    echo -e "${RED}✗ Generated code is out of date. Run: flutter pub run build_runner build${NC}"
    FAILURES=$((FAILURES + 1))
else
    echo -e "${GREEN}✓ Generated code is up to date${NC}"
fi

# Cleanup
cd "$REPO_ROOT/functions"
if [ -d "venv" ]; then
    deactivate 2>/dev/null || true
fi

# Summary
echo -e "\n${YELLOW}========================================${NC}"
if [ $FAILURES -gt 0 ]; then
    echo -e "${RED}✗ $FAILURES validation(s) failed${NC}"
    echo -e "${YELLOW}Schema consistency check FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo -e "${GREEN}✓ Python schema contracts ↔ Dart models consistency verified${NC}"
    exit 0
fi
