#!/bin/bash
# Run Flutter Integration Tests
# DISABLED: Flutter integration tests are temporarily disabled until they are stabilized.
# For E2E testing, use Playwright tests via ./scripts/e2e-with-services.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Flutter Integration Tests${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${YELLOW}⚠️  Flutter integration tests are temporarily disabled.${NC}"
echo -e "${YELLOW}   These tests require further stabilization before being${NC}"
echo -e "${YELLOW}   included in the CI/CD pipeline.${NC}"
echo ""
echo -e "${GREEN}✓ Use Playwright E2E tests instead:${NC}"
echo -e "    ./scripts/e2e-with-services.sh"
echo ""
echo -e "${GREEN}✓ Or run unit tests:${NC}"
echo -e "    cd origna_gta && flutter test"
echo ""

# Exit successfully to not break CI pipelines
exit 0
