#!/bin/bash
# run-e2e-tests.sh - Quick E2E test runner for OrignaGTA
# Assumes services are already running

set -e

echo "🧪 OrignaGTA E2E Tests Runner"
echo "=============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# Optional tuning
# - E2E_WORKERS: override Playwright workers (e.g. 4)
# - E2E_PROJECT: override Playwright project (default: chromium)
E2E_WORKERS="${E2E_WORKERS:-}"
E2E_PROJECT="${E2E_PROJECT:-}"

# Check if services are running
check_services() {
    local all_ok=true
    
    echo -e "\n📡 Checking services..."
    
    if curl -s http://localhost:5005 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Web server (5005)"
    else
        echo -e "  ${RED}✗${NC} Web server (5005) - NOT RUNNING"
        all_ok=false
    fi
    
    if curl -s http://localhost:9099 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Auth emulator (9099)"
    else
        echo -e "  ${RED}✗${NC} Auth emulator (9099) - NOT RUNNING"
        all_ok=false
    fi
    
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Firestore emulator (8080)"
    else
        echo -e "  ${RED}✗${NC} Firestore emulator (8080) - NOT RUNNING"
        all_ok=false
    fi
    
    if [ "$all_ok" = false ]; then
        echo -e "\n${YELLOW}WARNING: Some services are not running.${NC}"
        echo "Start services with:"
        echo "  firebase emulators:start --only=auth,firestore,functions,storage &"
        echo "  npx serve -s origna_gta/build/web -l 5005 &"
        return 1
    fi
    
    echo -e "${GREEN}All services running!${NC}"
    return 0
}

# Parse arguments
TEST_FILE=""
PROJECT="chromium"
UI_MODE=false

case "${1:-all}" in
    flutter|-f)
        TEST_FILE="flutter-web-e2e.spec.ts"
        ;;
    smoke|-s)
        TEST_FILE="full-marketplace-e2e.spec.ts"
        ;;
    all|-a|"")
        TEST_FILE="flutter-web-e2e.spec.ts full-marketplace-e2e.spec.ts"
        ;;
    --ui)
        UI_MODE=true
        TEST_FILE="flutter-web-e2e.spec.ts full-marketplace-e2e.spec.ts"
        ;;
    --help|-h)
        echo "Usage: $0 [flutter|smoke|all|--ui|--help]"
        echo ""
        echo "Options:"
        echo "  flutter, -f    Run Flutter Web E2E tests"
        echo "  smoke, -s      Run Smoke tests"
        echo "  all, -a        Run all tests (default)"
        echo "  --ui           Run with Playwright UI"
        echo "  --help, -h     Show this help"
        exit 0
        ;;
    *)
        TEST_FILE="$1"
        ;;
esac

if [ -n "$E2E_PROJECT" ]; then
    PROJECT="$E2E_PROJECT"
fi

cd "$PROJECT_DIR/e2e"

# Check services
check_services || exit 1

# Build and run command
if [ "$UI_MODE" = true ]; then
    CMD="npx playwright test $TEST_FILE --ui"
else
    # Do not force --workers=1; let playwright.config.ts decide.
    # If you want to override explicitly, set E2E_WORKERS (ex: E2E_WORKERS=4).
    WORKERS_FLAG=""
    if [ -n "$E2E_WORKERS" ]; then
        WORKERS_FLAG="--workers=$E2E_WORKERS"
    fi
    CMD="npx playwright test $TEST_FILE --project=$PROJECT --reporter=list $WORKERS_FLAG"
fi

echo -e "\n🚀 Running: $CMD\n"
eval $CMD

echo -e "\n${GREEN}✅ Tests completed!${NC}"
echo "✅ Tests completed!"