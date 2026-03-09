#!/bin/bash
# 🚀 Production Deployment Script
# Ensures all checks pass before deploying to production

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "🚀 Production Deployment Checklist"
echo "===================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

# Function to check status
check_status() {
  local name=$1
  local command=$2
  
  echo -n "⏳ $name ... "
  if eval "$command" > /tmp/check_output.txt 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((PASSED++))
  else
    echo -e "${RED}✗${NC}"
    echo "   Error output:"
    cat /tmp/check_output.txt | sed 's/^/   /'
    ((FAILED++))
  fi
}

# ============================================================================
# PRE-DEPLOYMENT CHECKS
# ============================================================================

echo -e "${BLUE}1. Code Quality Checks${NC}"
check_status "Flutter analyzer" "cd origna_gta && flutter analyze"
check_status "Dart format" "cd origna_gta && dart format --set-exit-if-changed lib test"

echo ""
echo -e "${BLUE}2. Test Suite${NC}"
check_status "Backend tests" "cd functions && pytest tests/ -q"
check_status "Frontend tests" "cd origna_gta && flutter test --reporter=expanded"

echo ""
echo -e "${BLUE}3. Security Checks${NC}"
check_status "No exposed secrets" "! grep -r 'API_KEY\|SECRET\|PASSWORD' functions/config.py origna_gta/lib | grep -v '# SAFE\|_load_secret\|os.environ'"
check_status "No print statements" "! grep -r 'print(' functions/handlers origna_gta/lib/screens | grep -v 'debugPrint'"
check_status "IS_EMULATOR in config" "grep 'IS_EMULATOR = ' functions/config.py | grep 'FUNCTIONS_EMULATOR'"

echo ""
echo -e "${BLUE}4. Build Artifacts${NC}"
check_status "Flutter web build" "cd origna_gta && flutter build web --release"
check_status "Functions bundle" "cd functions && pip install -r requirements.txt > /dev/null 2>&1 && python -m compileall handlers/ > /dev/null 2>&1"

echo ""
echo -e "${BLUE}5. Environment Configuration${NC}"
check_status ".env not in repo" "! git ls-files | grep '\.env'"
check_status "CI configured for production" "grep 'FUNCTIONS_EMULATOR.*false' .github/workflows/deploy.yml"

# ============================================================================
# RESULTS
# ============================================================================

echo ""
echo "===================================="
echo -e "${BLUE}Deployment Checklist Results${NC}"
echo "===================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ ALL CHECKS PASSED - READY FOR PRODUCTION${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Commit changes: git add . && git commit -m 'chore: ready for production'"
  echo "2. Push to main: git push origin main"
  echo "3. Firebase will auto-deploy: firebase deploy --only functions,hosting"
  echo ""
  echo "Production URL: https://orignagta.ca"
  exit 0
else
  echo -e "${RED}❌ DEPLOYMENT BLOCKED - FIX ERRORS ABOVE${NC}"
  echo ""
  echo "Failed checks: $FAILED"
  exit 1
fi
