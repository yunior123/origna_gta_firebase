#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_DIR/origna_gta"

TARGET="${1:-integration_test/app_test.dart}"
DRIVER="test_driver/integration_test.dart"

ENVIRONMENT_VALUE="${ENVIRONMENT:-dev}"
USE_EMULATORS_VALUE="${USE_EMULATORS:-false}"
FIREBASE_PROJECT_ID_VALUE="${FIREBASE_PROJECT_ID:-orignagta-dev}"
STRICT_INTEGRATION_VALUE="${STRICT_INTEGRATION:-true}"

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "chromedriver not found in PATH. Install it (brew install chromedriver or npm i -g chromedriver)." >&2
  exit 1
fi

cleanup() {
  if [[ -n "${CHROMEDRIVER_PID:-}" ]]; then
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Ensure port 4444 is free (Flutter web integration tests expect WebDriver at 4444)
if lsof -ti :4444 >/dev/null 2>&1; then
  echo "Port 4444 is already in use. Stop the process on 4444 and retry." >&2
  lsof -ti :4444 || true
  exit 1
fi

echo "Starting chromedriver on port 4444..."
chromedriver --port=4444 >/tmp/origna_chromedriver.log 2>&1 &
CHROMEDRIVER_PID=$!

# Wait until chromedriver is up
for _ in {1..30}; do
  if curl -s http://localhost:4444/status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -s http://localhost:4444/status >/dev/null 2>&1; then
  echo "chromedriver failed to start (see /tmp/origna_chromedriver.log)" >&2
  tail -50 /tmp/origna_chromedriver.log || true
  exit 1
fi

echo "Running Flutter integration test: $TARGET"
cd "$APP_DIR"
flutter drive \
  --driver="$DRIVER" \
  --target="$TARGET" \
  -d web-server \
  --browser-name=chrome \
  --headless \
  --dart-define=ENVIRONMENT="$ENVIRONMENT_VALUE" \
  --dart-define=USE_EMULATORS="$USE_EMULATORS_VALUE" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_VALUE" \
  --dart-define=STRICT_INTEGRATION="$STRICT_INTEGRATION_VALUE" \
