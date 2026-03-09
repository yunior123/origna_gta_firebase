#!/bin/bash
# =============================================================================
# 🧪  Run Human Workflow Integration Tests
# =============================================================================
# Orchestrates the full test pipeline on a physical iPhone:
#   1. Verify Firebase emulators are running
#   2. Seed emulator data
#   3. Verify Stripe CLI is forwarding webhooks
#   4. Run Flutter integration tests (human_workflows_test.dart)
#   5. (Optional) Run Playwright Stripe payment E2E
#   6. Print pass/fail summary
#
# Usage:
#   ./scripts/run-human-tests.sh              # auto-detect device
#   ./scripts/run-human-tests.sh <DEVICE_ID>  # specific device
#   ./scripts/run-human-tests.sh --skip-seed  # skip reseeding
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DEVICE_ID=""
SKIP_SEED=false

# ── Parse args ───────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --skip-seed) SKIP_SEED=true ;;
    *)           DEVICE_ID="$arg" ;;
  esac
done

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        🧪  Human Workflow Integration Tests                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Check Firebase Emulators ──────────────────────────────────────────────
echo -e "${YELLOW}[1/5] Checking Firebase Emulators...${NC}"
EMULATORS_OK=true
for port in 9099 8080 5001 9199; do
  if ! curl -s "http://127.0.0.1:$port" >/dev/null 2>&1; then
    EMULATORS_OK=false
    echo -e "  ${RED}✗ Port $port not responding${NC}"
  fi
done

if [ "$EMULATORS_OK" = false ]; then
  echo -e "${RED}❌ Firebase emulators are not running.${NC}"
  echo -e "   Start them first:  ${BLUE}./start-dev.sh${NC}"
  exit 1
fi
echo -e "  ${GREEN}✓ All emulators responding (Auth 9099, Firestore 8080, Functions 5001, Storage 9199)${NC}"

# ── 2. Seed Emulator Data ────────────────────────────────────────────────────
if [ "$SKIP_SEED" = true ]; then
  echo -e "${YELLOW}[2/5] Skipping seed (--skip-seed)${NC}"
else
  echo -e "${YELLOW}[2/5] Seeding emulator data...${NC}"
  cd "$REPO_ROOT/e2e"
  if npx ts-node seed-emulator.ts 2>&1; then
    echo -e "  ${GREEN}✓ Emulator seeded successfully${NC}"
  else
    echo -e "  ${RED}❌ Seed failed — tests may lack data${NC}"
  fi
  cd "$REPO_ROOT"
fi

# ── 3. Check Stripe CLI ─────────────────────────────────────────────────────
echo -e "${YELLOW}[3/5] Checking Stripe CLI webhook forwarding...${NC}"
if pgrep -f "stripe listen" >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓ Stripe CLI is forwarding webhooks${NC}"
else
  echo -e "  ${YELLOW}⚠️  Stripe CLI not detected — payment tests will be skipped${NC}"
  echo -e "     Start via: stripe listen --forward-to http://127.0.0.1:5001/orignagta/us-central1/stripe_webhook"
fi

# ── 4. Detect Device ────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/5] Detecting Flutter device...${NC}"
if [ -z "$DEVICE_ID" ]; then
  # Auto-detect first connected iOS device
  DEVICE_ID=$(cd "$REPO_ROOT/origna_gta" && flutter devices 2>/dev/null \
    | grep -i 'ios\|iphone' \
    | head -1 \
    | sed 's/.*•[[:space:]]*//' \
    | awk '{print $1}' \
    || true)
  if [ -z "$DEVICE_ID" ]; then
    echo -e "  ${YELLOW}No iOS device found. Using default device.${NC}"
    DEVICE_ID=""
  fi
fi

if [ -n "$DEVICE_ID" ]; then
  echo -e "  ${GREEN}✓ Using device: $DEVICE_ID${NC}"
  DEVICE_FLAG="-d $DEVICE_ID"
else
  echo -e "  ${YELLOW}⚠️  Running with default Flutter device${NC}"
  DEVICE_FLAG=""
fi

# ── 5. Run Flutter Integration Tests ────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Running human_workflows_test.dart${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$REPO_ROOT/origna_gta"

START_TIME=$(date +%s)

if flutter test integration_test/human_workflows_test.dart $DEVICE_FLAG --reporter expanded 2>&1; then
  FLUTTER_RESULT=0
else
  FLUTTER_RESULT=$?
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Test Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Duration: ${DURATION}s"
echo ""

if [ $FLUTTER_RESULT -eq 0 ]; then
  echo -e "  ${GREEN}✅  All human workflow tests PASSED${NC}"
  echo ""
  echo -e "  ${BLUE}Next step:${NC} Run Playwright Stripe E2E test:"
  echo -e "    cd e2e && npx playwright test stripe-payment-e2e.spec.ts"
else
  echo -e "  ${RED}❌  Some tests FAILED (exit code: $FLUTTER_RESULT)${NC}"
  echo ""
  echo -e "  ${YELLOW}Tips:${NC}"
  echo "    • Check emulator host IP in lib/main_test.dart (currently 192.168.2.42)"
  echo "    • Ensure emulators were seeded: cd e2e && npx ts-node seed-emulator.ts"
  echo "    • Review test output above for specific failures"
fi

echo ""
exit $FLUTTER_RESULT
