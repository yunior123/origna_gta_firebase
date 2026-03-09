#!/bin/bash
# Build and deploy script with schema validation
# Usage: ./scripts/deploy_with_validation.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}OrignaGta Deployment with Validation${NC}"
echo -e "${YELLOW}========================================${NC}"

# 1. Validate schema consistency
echo -e "\n${YELLOW}[1/5] Validating schema consistency...${NC}"
if "$REPO_ROOT/scripts/validate_schema_consistency.sh"; then
    echo -e "${GREEN}✓ Schema consistency validated${NC}"
else
    echo -e "${RED}✗ Schema validation failed - aborting deployment${NC}"
    exit 1
fi

# 2. Run all tests
echo -e "\n${YELLOW}[2/5] Running all tests...${NC}"
if "$REPO_ROOT/scripts/run_all_tests.sh"; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}✗ Tests failed - aborting deployment${NC}"
    exit 1
fi

# 3. Build Flutter (with explicit ENVIRONMENT=production)
echo -e "\n${YELLOW}[3/5] Building Flutter app for PRODUCTION...${NC}"
cd "$REPO_ROOT/origna_gta"
if flutter build web --release --dart-define=ENVIRONMENT=production; then
    echo -e "${GREEN}✓ Flutter PRODUCTION build successful${NC}"
else
    echo -e "${RED}✗ Flutter build failed${NC}"
    exit 1
fi

# 4. Deploy Firestore rules
echo -e "\n${YELLOW}[4/5] Deploying Firestore rules...${NC}"
cd "$REPO_ROOT"
if firebase deploy --only firestore:rules; then
    echo -e "${GREEN}✓ Firestore rules deployed${NC}"
else
    echo -e "${RED}✗ Firestore rules deployment failed${NC}"
    exit 1
fi

# 5. Deploy Firebase functions
echo -e "\n${YELLOW}[5/6] Deploying Firebase functions...${NC}"
cd "$REPO_ROOT"
if firebase deploy --only functions --force; then
    echo -e "${GREEN}✓ Firebase functions deployed${NC}"
else
    echo -e "${RED}✗ Firebase functions deployment failed${NC}"
    exit 1
fi

# 6. Record deploy versions
echo -e "\n${YELLOW}[6/6] Recording deploy versions...${NC}"
cd "$REPO_ROOT"
python3 scripts/record_deploy_version.py --env=dev
python3 scripts/record_deploy_version.py --env=staging
python3 scripts/record_deploy_version.py --env=prod
echo -e "${GREEN}✓ Deploy versions recorded${NC}"

# Summary
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo -e "${GREEN}  - Schema validated${NC}"
echo -e "${GREEN}  - Tests passed${NC}"
echo -e "${GREEN}  - Flutter built${NC}"
echo -e "${GREEN}  - Rules deployed${NC}"
echo -e "${GREEN}  - Functions deployed${NC}"
echo -e "${GREEN}  - Versions recorded${NC}"
echo -e "${YELLOW}========================================${NC}"
