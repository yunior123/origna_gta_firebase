#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/origna_gta"
E2E_DIR="$REPO_ROOT/e2e"

TARGET="${1:-integration_test/all_tests.dart}"
DRIVER="test_driver/integration_test.dart"
LOG_DIR="/tmp/origna_db_matrix"

mkdir -p "$LOG_DIR"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cleanup_test_processes() {
  pkill -9 -f "flutter.*drive" 2>/dev/null || true
  pkill -9 -f "dart.*integration_test" 2>/dev/null || true
  pkill -9 -f "chromedriver.*4444" 2>/dev/null || true
  sleep 1
}

stop_emulators() {
  pkill -9 -f "firebase emulators" 2>/dev/null || true
  pkill -9 -f "java.*firestore" 2>/dev/null || true
  pkill -9 -f "java.*emulator" 2>/dev/null || true
  sleep 2
}

start_emulators_empty() {
  echo -e "${YELLOW}Starting Firebase emulators (EMPTY DB)...${NC}"
  (
    cd "$REPO_ROOT"
    firebase emulators:start --only auth,firestore,functions,storage >"$LOG_DIR/firebase-empty.log" 2>&1
  ) &
  EMULATOR_PID=$!

  for _ in {1..60}; do
    if curl -s http://127.0.0.1:4400/emulators >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Emulators ready${NC}"
      return 0
    fi
    sleep 2
  done

  echo -e "${RED}✗ Emulators failed to start${NC}"
  tail -n 80 "$LOG_DIR/firebase-empty.log" || true
  exit 1
}

start_chromedriver() {
  echo -e "${YELLOW}Starting chromedriver :4444...${NC}"
  chromedriver --port=4444 >"$LOG_DIR/chromedriver.log" 2>&1 &
  CHROMEDRIVER_PID=$!

  for _ in {1..30}; do
    if curl -s http://localhost:4444/status >/dev/null 2>&1; then
      echo -e "${GREEN}✓ ChromeDriver ready${NC}"
      return 0
    fi
    sleep 1
  done

  echo -e "${RED}✗ ChromeDriver failed${NC}"
  tail -n 60 "$LOG_DIR/chromedriver.log" || true
  exit 1
}

run_flutter_drive() {
  local mode="$1"
  local log_file="$LOG_DIR/flutter-${mode}.log"

  echo -e "${BLUE}Running Flutter integration (${mode})...${NC}"
  (
    cd "$APP_DIR"
    flutter drive \
      --driver="$DRIVER" \
      --target="$TARGET" \
      -d chrome \
      --dart-define=ENVIRONMENT=emulator \
      --dart-define=USE_EMULATORS=true 2>&1 | tee "$log_file"
  )
}

seed_full_db() {
  echo -e "${YELLOW}Seeding full DB (users/products/orders/admin)...${NC}"

  (
    cd "$E2E_DIR"
    npx ts-node mega-seed.ts
  )

  if [[ -f "$E2E_DIR/scripts/seed/seed-orders.py" ]]; then
    python3 "$E2E_DIR/scripts/seed/seed-orders.py"
  fi

  echo -e "${GREEN}✓ Full seed completed${NC}"
}

trap 'cleanup_test_processes; stop_emulators' EXIT

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}DB Matrix Integration Runner${NC}"
echo -e "${BLUE}Target: ${TARGET}${NC}"
echo -e "${BLUE}============================================${NC}"

cleanup_test_processes
stop_emulators

# 1) Empty DB run
start_emulators_empty
start_chromedriver
run_flutter_drive "empty"

# reset before full seed scenario
cleanup_test_processes
stop_emulators
start_emulators_empty
start_chromedriver
seed_full_db
run_flutter_drive "full-seeded"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Done. Logs:${NC} ${LOG_DIR}"
echo -e "${GREEN}- flutter-empty.log${NC}"
echo -e "${GREEN}- flutter-full-seeded.log${NC}"
echo -e "${GREEN}- firebase-empty.log${NC}"
echo -e "${GREEN}- chromedriver.log${NC}"
echo -e "${GREEN}============================================${NC}"
