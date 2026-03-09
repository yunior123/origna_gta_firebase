#!/usr/bin/env bash

# Strict quality gate:
# - Backend Python coverage threshold
# - Flutter coverage threshold
# - Real Playwright E2E smoke set
# - Playwright coverage threshold
#
# Defaults intentionally set to 100 to enforce strict mode.

set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BACKEND_THRESHOLD="${BACKEND_THRESHOLD:-100}"
BACKEND_GATE_MODE="${BACKEND_GATE_MODE:-strict}"
BACKEND_BASELINE="${BACKEND_BASELINE:-0}"
BACKEND_MIN_DELTA="${BACKEND_MIN_DELTA:-0}"
FLUTTER_THRESHOLD="${FLUTTER_THRESHOLD:-100}"
E2E_SPECS="${E2E_SPECS:-${E2E_SPEC:-playwright_ui/smoke-home-profile.spec.ts,playwright_ui/buyer-flow.spec.ts,playwright_ui/seller-flow.spec.ts,playwright_ui/order-lifecycle.spec.ts}}"
E2E_RANDOM_COUNT="${E2E_RANDOM_COUNT:-0}"
E2E_CONFIG="${E2E_CONFIG:-playwright.config.dev.ts}"
E2E_PROJECT="${E2E_PROJECT:-chromium}"
E2E_WORKERS="${E2E_WORKERS:-1}"
E2E_FAIL_ON_FLAKY="${E2E_FAIL_ON_FLAKY:-true}"
FLUTTER_TEST_TARGETS="${FLUTTER_TEST_TARGETS:-test/unit,test/widget,test/widget_test.dart}"
FLUTTER_COVERAGE_TARGETS="${FLUTTER_COVERAGE_TARGETS:-test/coverage_gate_test.dart}"
RUN_FLUTTER_INTEGRATION_COVERAGE="${RUN_FLUTTER_INTEGRATION_COVERAGE:-false}"
FLUTTER_INTEGRATION_THRESHOLD="${FLUTTER_INTEGRATION_THRESHOLD:-100}"
FLUTTER_INTEGRATION_COVERAGE_TARGETS="${FLUTTER_INTEGRATION_COVERAGE_TARGETS:-integration_test/coverage_gate_integration_test.dart}"
FLUTTER_INTEGRATION_RANDOM_COUNT="${FLUTTER_INTEGRATION_RANDOM_COUNT:-0}"
FLUTTER_INTEGRATION_DEVICE="${FLUTTER_INTEGRATION_DEVICE:-}"
FLUTTER_INTEGRATION_USE_XVFB="${FLUTTER_INTEGRATION_USE_XVFB:-false}"
PLAYWRIGHT_THRESHOLD="${PLAYWRIGHT_THRESHOLD:-100}"
PLAYWRIGHT_COVERAGE_TARGETS="${PLAYWRIGHT_COVERAGE_TARGETS:-playwright_ui/coverage-gate.spec.ts}"
PLAYWRIGHT_COVERAGE_INCLUDE="${PLAYWRIGHT_COVERAGE_INCLUDE:-playwright_ui/coverage_gate.ts}"
RUN_FLUTTER_GOLDENS="${RUN_FLUTTER_GOLDENS:-false}"
FLUTTER_GOLDEN_TEST_PATH="${FLUTTER_GOLDEN_TEST_PATH:-test/golden_previews_test.dart}"
BACKEND_TIMEOUT_SECONDS="${BACKEND_TIMEOUT_SECONDS:-0}"
FLUTTER_TEST_TIMEOUT_SECONDS="${FLUTTER_TEST_TIMEOUT_SECONDS:-0}"
FLUTTER_COVERAGE_TIMEOUT_SECONDS="${FLUTTER_COVERAGE_TIMEOUT_SECONDS:-0}"
FLUTTER_INTEGRATION_TIMEOUT_SECONDS="${FLUTTER_INTEGRATION_TIMEOUT_SECONDS:-0}"
FLUTTER_GOLDEN_TIMEOUT_SECONDS="${FLUTTER_GOLDEN_TIMEOUT_SECONDS:-0}"
E2E_SPEC_TIMEOUT_SECONDS="${E2E_SPEC_TIMEOUT_SECONDS:-0}"
PLAYWRIGHT_COVERAGE_TIMEOUT_SECONDS="${PLAYWRIGHT_COVERAGE_TIMEOUT_SECONDS:-0}"

RUN_BACKEND=true
RUN_FLUTTER=true
RUN_E2E=true
ALLOW_LOCAL_HEAVY="${ALLOW_LOCAL_HEAVY:-false}"

if [[ -n "${CI:-}" || -n "${CM_BUILD_ID:-}" ]]; then
  BACKEND_TIMEOUT_SECONDS="${BACKEND_TIMEOUT_SECONDS:-1800}"
  FLUTTER_TEST_TIMEOUT_SECONDS="${FLUTTER_TEST_TIMEOUT_SECONDS:-900}"
  FLUTTER_COVERAGE_TIMEOUT_SECONDS="${FLUTTER_COVERAGE_TIMEOUT_SECONDS:-900}"
  FLUTTER_INTEGRATION_TIMEOUT_SECONDS="${FLUTTER_INTEGRATION_TIMEOUT_SECONDS:-1200}"
  FLUTTER_GOLDEN_TIMEOUT_SECONDS="${FLUTTER_GOLDEN_TIMEOUT_SECONDS:-900}"
  E2E_SPEC_TIMEOUT_SECONDS="${E2E_SPEC_TIMEOUT_SECONDS:-900}"
  PLAYWRIGHT_COVERAGE_TIMEOUT_SECONDS="${PLAYWRIGHT_COVERAGE_TIMEOUT_SECONDS:-600}"
fi

print_usage() {
  cat <<'EOF'
Usage: ./scripts/run_quality_gate.sh [options]

Options:
  --backend-threshold N   Backend coverage threshold (default: env BACKEND_THRESHOLD or 100)
  --backend-gate-mode M   Backend gate mode: strict|incremental (default: env BACKEND_GATE_MODE or strict)
  --backend-baseline N    Backend baseline coverage % for incremental mode (default: env BACKEND_BASELINE or 0)
  --backend-min-delta N   Required backend +delta coverage % over baseline in incremental mode (default: env BACKEND_MIN_DELTA or 0)
  --flutter-threshold N   Flutter coverage threshold (default: env FLUTTER_THRESHOLD or 100)
  --flutter-targets CSV   Flutter test targets under origna_gta/ (default: test/unit,test/widget,test/widget_test.dart)
  --flutter-coverage-targets CSV
                         Flutter targets used for coverage measurement (default: test/coverage_gate_test.dart)
  --run-flutter-integration-coverage
                         Enable Flutter integration coverage gate (default: disabled)
  --flutter-integration-threshold N
                         Flutter integration coverage threshold (default: env FLUTTER_INTEGRATION_THRESHOLD or 100)
  --flutter-integration-coverage-targets CSV
                         Flutter integration targets used for coverage measurement
                         (default: integration_test/coverage_gate_integration_test.dart)
  --flutter-integration-device NAME
                         Device used for Flutter integration coverage (example: linux)
  --flutter-integration-use-xvfb
                         Wrap Flutter integration coverage runs in xvfb-run -a
  --run-flutter-goldens   Run Flutter golden test suite (opt-in)
  --flutter-golden-test P Golden test path under origna_gta/ (default: test/golden_previews_test.dart)
  --playwright-threshold N
                         Playwright coverage threshold (default: env PLAYWRIGHT_THRESHOLD or 100)
  --playwright-coverage-targets CSV
                         Playwright targets used for coverage measurement (default: playwright_ui/coverage-gate.spec.ts)
  --playwright-coverage-include CSV
                         Playwright source files included in coverage measurement (default: playwright_ui/coverage_gate.ts)
  --e2e-spec PATH         Playwright spec path under e2e/ (single override, backward-compatible)
  --e2e-specs CSV         Comma-separated Playwright specs under e2e/
  --e2e-config FILE       Playwright config file under e2e/ (default: playwright.config.dev.ts)
  --e2e-project NAME      Playwright project (default: chromium)
  --e2e-workers N         Playwright workers (default: 1)
  --e2e-random-count N    Run N random Playwright E2E specs instead of all (default: 0 = all)
  --flutter-integration-random-count N Run N random Flutter integration targets (default: 0 = all)
  --skip-backend          Skip backend coverage gate
  --skip-flutter          Skip Flutter coverage gate
  --skip-e2e              Skip Playwright E2E gate
  --allow-local-heavy     Allow heavy Flutter/E2E gates on local machines (default: off)
  --help, -h              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-threshold)
      BACKEND_THRESHOLD="$2"
      shift 2
      ;;
    --backend-gate-mode)
      BACKEND_GATE_MODE="$2"
      shift 2
      ;;
    --backend-baseline)
      BACKEND_BASELINE="$2"
      shift 2
      ;;
    --backend-min-delta)
      BACKEND_MIN_DELTA="$2"
      shift 2
      ;;
    --flutter-threshold)
      FLUTTER_THRESHOLD="$2"
      shift 2
      ;;
    --flutter-targets)
      FLUTTER_TEST_TARGETS="$2"
      shift 2
      ;;
    --flutter-coverage-targets)
      FLUTTER_COVERAGE_TARGETS="$2"
      shift 2
      ;;
    --run-flutter-integration-coverage)
      RUN_FLUTTER_INTEGRATION_COVERAGE=true
      shift
      ;;
    --flutter-integration-threshold)
      FLUTTER_INTEGRATION_THRESHOLD="$2"
      shift 2
      ;;
    --flutter-integration-coverage-targets)
      FLUTTER_INTEGRATION_COVERAGE_TARGETS="$2"
      shift 2
      ;;
    --flutter-integration-device)
      FLUTTER_INTEGRATION_DEVICE="$2"
      shift 2
      ;;
    --flutter-integration-use-xvfb)
      FLUTTER_INTEGRATION_USE_XVFB=true
      shift
      ;;
    --playwright-threshold)
      PLAYWRIGHT_THRESHOLD="$2"
      shift 2
      ;;
    --playwright-coverage-targets)
      PLAYWRIGHT_COVERAGE_TARGETS="$2"
      shift 2
      ;;
    --playwright-coverage-include)
      PLAYWRIGHT_COVERAGE_INCLUDE="$2"
      shift 2
      ;;
    --run-flutter-goldens)
      RUN_FLUTTER_GOLDENS=true
      shift
      ;;
    --flutter-golden-test)
      FLUTTER_GOLDEN_TEST_PATH="$2"
      shift 2
      ;;
    --e2e-spec|--e2e-specs)
      E2E_SPECS="$2"
      shift 2
      ;;
    --e2e-config)
      E2E_CONFIG="$2"
      shift 2
      ;;
    --e2e-project)
      E2E_PROJECT="$2"
      shift 2
      ;;
    --e2e-workers)
      E2E_WORKERS="$2"
      shift 2
      ;;
    --e2e-random-count)
      E2E_RANDOM_COUNT="$2"
      shift 2
      ;;
    --flutter-integration-random-count)
      FLUTTER_INTEGRATION_RANDOM_COUNT="$2"
      shift 2
      ;;
    --skip-backend)
      RUN_BACKEND=false
      shift
      ;;
    --skip-flutter)
      RUN_FLUTTER=false
      shift
      ;;
    --skip-e2e)
      RUN_E2E=false
      shift
      ;;
    --allow-local-heavy)
      ALLOW_LOCAL_HEAVY=true
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 2
      ;;
  esac
done

case "$BACKEND_GATE_MODE" in
  strict|incremental) ;;
  *)
    echo "Invalid --backend-gate-mode/BACKEND_GATE_MODE: ${BACKEND_GATE_MODE} (expected strict|incremental)" >&2
    exit 2
    ;;
esac

# Protect low-resource local machines: by default run only backend gate locally.
if [[ -z "${CI:-}" && -z "${CM_BUILD_ID:-}" && "$ALLOW_LOCAL_HEAVY" != "true" ]]; then
  if [[ "$RUN_FLUTTER" == true || "$RUN_E2E" == true ]]; then
    echo "Local safety mode: skipping Flutter and Playwright gates to reduce RAM/disk usage."
    echo "Run full pipeline in GitHub Actions/Codemagic, or pass --allow-local-heavy if you intentionally want local heavy execution."
    RUN_FLUTTER=false
    RUN_E2E=false
  fi
fi

FAILURES=0

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

run_with_optional_timeout() {
  local timeout_seconds="$1"
  shift

  if [[ "$timeout_seconds" =~ ^[0-9]+$ ]] && [[ "$timeout_seconds" -gt 0 ]]; then
    python3 - "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
cmd = sys.argv[2:]

try:
    result = subprocess.run(cmd, timeout=timeout_seconds)
    raise SystemExit(result.returncode)
except subprocess.TimeoutExpired:
    print(
        f"Command timed out after {timeout_seconds}s: {' '.join(cmd)}",
        file=sys.stderr,
    )
    raise SystemExit(124)
PY
  else
    "$@"
  fi
}

backend_gap_report() {
  python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

xml_path = Path("coverage.xml")
if not xml_path.exists():
    print("No backend XML coverage report found at functions/coverage.xml")
    raise SystemExit(0)

root = ET.parse(xml_path).getroot()
rows = []
for cls in root.findall(".//class"):
    filename = cls.attrib.get("filename", "")
    lines = cls.findall("./lines/line")
    valid = len(lines)
    covered = sum(1 for line in lines if int(line.attrib.get("hits", "0")) > 0)
    if valid < 20:
        continue
    pct = (covered / valid * 100.0) if valid else 0.0
    rows.append((pct, valid, covered, filename))

rows.sort(key=lambda x: (x[0], -x[1], x[3]))
print("Lowest backend coverage files (min 20 executable lines):")
for pct, valid, covered, filename in rows[:15]:
    print(f"  - {filename}: {pct:.2f}% ({covered}/{valid})")
PY
}

flutter_gap_report() {
  python3 - <<'PY'
from pathlib import Path

lcov_path = Path("coverage_unit.info")
if not lcov_path.exists():
    print("No Flutter LCOV report found at origna_gta/coverage_unit.info")
    raise SystemExit(0)

rows = []
sf = None
lf = None
lh = None

for raw in lcov_path.read_text().splitlines():
    if raw.startswith("SF:"):
        sf = raw[3:]
        lf = None
        lh = None
    elif raw.startswith("LF:"):
        lf = int(raw[3:])
    elif raw.startswith("LH:"):
        lh = int(raw[3:])
    elif raw == "end_of_record":
        if sf is not None and lf is not None and lh is not None and lf >= 20:
            pct = (lh / lf * 100.0) if lf else 0.0
            rows.append((pct, lf, lh, sf))
        sf = None
        lf = None
        lh = None

rows.sort(key=lambda x: (x[0], -x[1], x[3]))
print("Lowest Flutter coverage files (min 20 executable lines):")
for pct, lf, lh, sf in rows[:15]:
    print(f"  - {sf}: {pct:.2f}% ({lh}/{lf})")
PY
}

check_flutter_threshold() {
  local threshold="$1"
  python3 - "$threshold" <<'PY'
import sys
from pathlib import Path

threshold = float(sys.argv[1])
lcov_path = Path("coverage_unit.info")
if not lcov_path.exists():
    print("coverage_unit.info not found", file=sys.stderr)
    raise SystemExit(2)

lf = 0
lh = 0
for line in lcov_path.read_text().splitlines():
    if line.startswith("LF:"):
        lf += int(line[3:])
    elif line.startswith("LH:"):
        lh += int(line[3:])

pct = (lh / lf * 100.0) if lf else 0.0
print(f"Flutter total line coverage: {pct:.2f}% ({lh}/{lf})")
if pct + 1e-9 < threshold:
    raise SystemExit(1)
PY
}

flutter_integration_gap_report() {
  python3 - <<'PY'
from pathlib import Path

lcov_path = Path("coverage_integration.info")
if not lcov_path.exists():
    print("No Flutter integration LCOV report found at origna_gta/coverage_integration.info")
    raise SystemExit(0)

rows = []
sf = None
lf = None
lh = None

for raw in lcov_path.read_text().splitlines():
    if raw.startswith("SF:"):
        sf = raw[3:]
        lf = None
        lh = None
    elif raw.startswith("LF:"):
        lf = int(raw[3:])
    elif raw.startswith("LH:"):
        lh = int(raw[3:])
    elif raw == "end_of_record":
        if sf is not None and lf is not None and lh is not None and lf >= 20:
            pct = (lh / lf * 100.0) if lf else 0.0
            rows.append((pct, lf, lh, sf))
        sf = None
        lf = None
        lh = None

rows.sort(key=lambda x: (x[0], -x[1], x[3]))
print("Lowest Flutter integration coverage files (min 20 executable lines):")
for pct, lf, lh, sf in rows[:15]:
    print(f"  - {sf}: {pct:.2f}% ({lh}/{lf})")
PY
}

check_flutter_integration_threshold() {
  local threshold="$1"
  python3 - "$threshold" <<'PY'
import sys
from pathlib import Path

threshold = float(sys.argv[1])
lcov_path = Path("coverage_integration.info")
if not lcov_path.exists():
    print("coverage_integration.info not found", file=sys.stderr)
    raise SystemExit(2)

lf = 0
lh = 0
for line in lcov_path.read_text().splitlines():
    if line.startswith("LF:"):
        lf += int(line[3:])
    elif line.startswith("LH:"):
        lh += int(line[3:])

pct = (lh / lf * 100.0) if lf else 0.0
print(f"Flutter integration total line coverage: {pct:.2f}% ({lh}/{lf})")
if pct + 1e-9 < threshold:
    raise SystemExit(1)
PY
}

playwright_gap_report() {
  local lcov_path="$1"
  python3 - "$lcov_path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.exists():
    print(f"No Playwright LCOV report found at {path}")
    raise SystemExit(0)

rows = []
sf = None
lf = None
lh = None

for raw in path.read_text().splitlines():
    if raw.startswith("SF:"):
        sf = raw[3:]
        lf = None
        lh = None
    elif raw.startswith("LF:"):
        lf = int(raw[3:])
    elif raw.startswith("LH:"):
        lh = int(raw[3:])
    elif raw == "end_of_record":
        if sf is not None and lf is not None and lh is not None:
            pct = (lh / lf * 100.0) if lf else 0.0
            rows.append((pct, lf, lh, sf))
        sf = None
        lf = None
        lh = None

rows.sort(key=lambda x: (x[0], -x[1], x[3]))
print("Lowest Playwright coverage files:")
for pct, lf, lh, sf in rows[:15]:
    print(f"  - {sf}: {pct:.2f}% ({lh}/{lf})")
PY
}

check_playwright_threshold() {
  local threshold="$1"
  local lcov_path="$2"
  python3 - "$threshold" "$lcov_path" <<'PY'
import sys
from pathlib import Path

threshold = float(sys.argv[1])
lcov_path = Path(sys.argv[2])
if not lcov_path.exists():
    print(f"{lcov_path} not found", file=sys.stderr)
    raise SystemExit(2)

lf = 0
lh = 0
for line in lcov_path.read_text().splitlines():
    if line.startswith("LF:"):
        lf += int(line[3:])
    elif line.startswith("LH:"):
        lh += int(line[3:])

pct = (lh / lf * 100.0) if lf else 0.0
print(f"Playwright total line coverage: {pct:.2f}% ({lh}/{lf})")
if pct + 1e-9 < threshold:
    raise SystemExit(1)
PY
}

check_backend_incremental_threshold() {
  local baseline="$1"
  local min_delta="$2"
  python3 - "$baseline" "$min_delta" <<'PY'
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

baseline = float(sys.argv[1])
min_delta = float(sys.argv[2])
required = baseline + min_delta

xml_path = Path("coverage.xml")
if not xml_path.exists():
    print("coverage.xml not found", file=sys.stderr)
    raise SystemExit(2)

root = ET.parse(xml_path).getroot()
line_rate = float(root.attrib.get("line-rate", "0") or "0")
pct = line_rate * 100.0
print(
    f"Backend total line coverage: {pct:.2f}% "
    f"(incremental mode; baseline={baseline:.2f}%, min_delta={min_delta:.2f}%, required={required:.2f}%)"
)
if pct + 1e-9 < required:
    raise SystemExit(1)
PY
}

if [[ "$RUN_BACKEND" == true ]]; then
  if [[ "$BACKEND_GATE_MODE" == "strict" ]]; then
    section "Backend Coverage Gate (strict threshold: ${BACKEND_THRESHOLD}%)"
  else
    section "Backend Coverage Gate (incremental baseline: ${BACKEND_BASELINE}% + delta: ${BACKEND_MIN_DELTA}%)"
  fi

  pushd "$ROOT_DIR/functions" >/dev/null || exit 1

  if ! python3 -c "import pytest_cov" >/dev/null 2>&1; then
    echo "Installing pytest-cov..."
    python3 -m pip install pytest-cov >/dev/null 2>&1 || true
  fi

  PYTEST_CMD=(
    pytest tests/
    --cov=handlers
    --cov=services
    --cov=models
    --cov=utils
    --cov-report=term-missing
    --cov-report=xml:coverage.xml
    -q
  )
  if [[ "$BACKEND_GATE_MODE" == "strict" ]]; then
    PYTEST_CMD+=(--cov-fail-under="$BACKEND_THRESHOLD")
  fi

  set +e
  run_with_optional_timeout "$BACKEND_TIMEOUT_SECONDS" "${PYTEST_CMD[@]}"
  TEST_STATUS=$?
  set -e

  backend_gap_report

  BACKEND_GATE_STATUS=0
  if [[ $TEST_STATUS -ne 0 ]]; then
    BACKEND_GATE_STATUS=1
  elif [[ "$BACKEND_GATE_MODE" == "incremental" ]]; then
    set +e
    check_backend_incremental_threshold "$BACKEND_BASELINE" "$BACKEND_MIN_DELTA"
    BACKEND_GATE_STATUS=$?
    set -e
  fi

  popd >/dev/null || exit 1

  if [[ $BACKEND_GATE_STATUS -ne 0 ]]; then
    echo "Backend coverage gate FAILED."
    FAILURES=$((FAILURES + 1))
  else
    echo "Backend coverage gate PASSED."
  fi
fi

if [[ "$RUN_FLUTTER" == true ]]; then
  section "Flutter Coverage Gate (threshold: ${FLUTTER_THRESHOLD}%)"
  pushd "$ROOT_DIR/origna_gta" >/dev/null || exit 1

  # 1) Always run the primary Flutter test matrix for behavior/regression safety.
  FLUTTER_TARGETS=()
  IFS=',' read -r -a RAW_FLUTTER_TARGETS <<< "$FLUTTER_TEST_TARGETS"
  for raw_target in "${RAW_FLUTTER_TARGETS[@]}"; do
    target="$(echo "$raw_target" | xargs)"
    [[ -z "$target" ]] && continue
    if [[ -e "$target" ]]; then
      FLUTTER_TARGETS+=("$target")
    else
      echo "Skipping missing Flutter target: $target"
    fi
  done

  if [[ ${#FLUTTER_TARGETS[@]} -eq 0 ]]; then
    echo "No Flutter test targets found from FLUTTER_TEST_TARGETS=$FLUTTER_TEST_TARGETS"
    FAILURES=$((FAILURES + 1))
  else
    echo "Running Flutter tests: ${FLUTTER_TARGETS[*]}"
    set +e
    run_with_optional_timeout "$FLUTTER_TEST_TIMEOUT_SECONDS" flutter test "${FLUTTER_TARGETS[@]}"
    TEST_STATUS=$?
    set -e

    if [[ $TEST_STATUS -ne 0 ]]; then
      echo "Flutter tests FAILED."
      FAILURES=$((FAILURES + 1))
    fi
  fi

  # 2) Run dedicated deterministic coverage targets and enforce threshold.
  FLUTTER_COV_TARGETS=()
  IFS=',' read -r -a RAW_FLUTTER_COV_TARGETS <<< "$FLUTTER_COVERAGE_TARGETS"
  for raw_cov_target in "${RAW_FLUTTER_COV_TARGETS[@]}"; do
    cov_target="$(echo "$raw_cov_target" | xargs)"
    [[ -z "$cov_target" ]] && continue
    if [[ -e "$cov_target" ]]; then
      FLUTTER_COV_TARGETS+=("$cov_target")
    else
      echo "Skipping missing Flutter coverage target: $cov_target"
    fi
  done

  if [[ ${#FLUTTER_COV_TARGETS[@]} -eq 0 ]]; then
    echo "No Flutter coverage targets found from FLUTTER_COVERAGE_TARGETS=$FLUTTER_COVERAGE_TARGETS"
    FAILURES=$((FAILURES + 1))
  else
    echo "Running Flutter coverage targets: ${FLUTTER_COV_TARGETS[*]}"
    set +e
    run_with_optional_timeout "$FLUTTER_COVERAGE_TIMEOUT_SECONDS" flutter test "${FLUTTER_COV_TARGETS[@]}" --coverage --coverage-path=coverage_unit.info
    COV_STATUS=$?
    set -e

    if [[ $COV_STATUS -ne 0 ]]; then
      echo "Flutter coverage targets FAILED."
      FAILURES=$((FAILURES + 1))
    else
      set +e
      check_flutter_threshold "$FLUTTER_THRESHOLD"
      THRESH_STATUS=$?
      set -e
      flutter_gap_report
      if [[ $THRESH_STATUS -ne 0 ]]; then
        echo "Flutter coverage gate FAILED."
        FAILURES=$((FAILURES + 1))
      else
        echo "Flutter coverage gate PASSED."
      fi
    fi
  fi

  if [[ "$RUN_FLUTTER_INTEGRATION_COVERAGE" == "true" ]]; then
    section "Flutter Integration Coverage Gate (threshold: ${FLUTTER_INTEGRATION_THRESHOLD}%)"

    FLUTTER_INT_COV_TARGETS=()
    IFS=',' read -r -a RAW_FLUTTER_INT_COV_TARGETS <<< "$FLUTTER_INTEGRATION_COVERAGE_TARGETS"
    for raw_int_cov_target in "${RAW_FLUTTER_INT_COV_TARGETS[@]}"; do
      int_cov_target="$(echo "$raw_int_cov_target" | xargs)"
      [[ -z "$int_cov_target" ]] && continue
      if [[ -e "$int_cov_target" ]]; then
        FLUTTER_INT_COV_TARGETS+=("$int_cov_target")
      elif [[ "$int_cov_target" == *"*"* ]]; then
        # Expand glob
        for f in $int_cov_target; do
          if [[ -e "$f" ]]; then
             FLUTTER_INT_COV_TARGETS+=("$f")
          fi
        done
      else
        echo "Skipping missing Flutter integration coverage target: $int_cov_target"
      fi
    done

    if [[ "$FLUTTER_INTEGRATION_RANDOM_COUNT" -gt 0 && "${#FLUTTER_INT_COV_TARGETS[@]}" -gt "$FLUTTER_INTEGRATION_RANDOM_COUNT" ]]; then
      echo "Randomly selecting $FLUTTER_INTEGRATION_RANDOM_COUNT Flutter integration specs from ${#FLUTTER_INT_COV_TARGETS[@]} total..."
      # Shuffle and pick N
      FLUTTER_INT_COV_TARGETS=($(shuf -e "${FLUTTER_INT_COV_TARGETS[@]}" | head -n "$FLUTTER_INTEGRATION_RANDOM_COUNT"))
    fi

    if [[ ${#FLUTTER_INT_COV_TARGETS[@]} -eq 0 ]]; then
      echo "No Flutter integration coverage targets found from FLUTTER_INTEGRATION_COVERAGE_TARGETS=$FLUTTER_INTEGRATION_COVERAGE_TARGETS"
      FAILURES=$((FAILURES + 1))
    else
      echo "Running Flutter integration coverage targets: ${FLUTTER_INT_COV_TARGETS[*]}"
      INTEGRATION_CMD=(flutter test "${FLUTTER_INT_COV_TARGETS[@]}" --coverage --coverage-path=coverage_integration.info)
      if [[ -n "$FLUTTER_INTEGRATION_DEVICE" ]]; then
        INTEGRATION_CMD+=(-d "$FLUTTER_INTEGRATION_DEVICE")
      fi
      if [[ "$FLUTTER_INTEGRATION_USE_XVFB" == "true" ]]; then
        INTEGRATION_CMD=(xvfb-run -a "${INTEGRATION_CMD[@]}")
      fi

      set +e
      run_with_optional_timeout "$FLUTTER_INTEGRATION_TIMEOUT_SECONDS" "${INTEGRATION_CMD[@]}"
      INT_COV_STATUS=$?
      set -e

      if [[ $INT_COV_STATUS -ne 0 ]]; then
        echo "Flutter integration coverage targets FAILED."
        FAILURES=$((FAILURES + 1))
      else
        set +e
        check_flutter_integration_threshold "$FLUTTER_INTEGRATION_THRESHOLD"
        INT_THRESH_STATUS=$?
        set -e
        flutter_integration_gap_report
        if [[ $INT_THRESH_STATUS -ne 0 ]]; then
          echo "Flutter integration coverage gate FAILED."
          FAILURES=$((FAILURES + 1))
        else
          echo "Flutter integration coverage gate PASSED."
        fi
      fi
    fi
  fi

  if [[ "$RUN_FLUTTER_GOLDENS" == "true" ]]; then
    section "Flutter Golden Gate (${FLUTTER_GOLDEN_TEST_PATH})"
    if [[ ! -e "$FLUTTER_GOLDEN_TEST_PATH" ]]; then
      echo "Flutter golden test path not found: $FLUTTER_GOLDEN_TEST_PATH"
      FAILURES=$((FAILURES + 1))
    else
      set +e
      run_with_optional_timeout "$FLUTTER_GOLDEN_TIMEOUT_SECONDS" flutter test "$FLUTTER_GOLDEN_TEST_PATH" --dart-define=RUN_GOLDENS=true
      GOLDEN_STATUS=$?
      set -e
      if [[ $GOLDEN_STATUS -ne 0 ]]; then
        echo "Flutter golden gate FAILED."
        FAILURES=$((FAILURES + 1))
      else
        echo "Flutter golden gate PASSED."
      fi
    fi
  fi

  popd >/dev/null || exit 1
fi

if [[ "$RUN_E2E" == true ]]; then
  section "Real Playwright E2E Gate (${E2E_SPECS})"
  pushd "$ROOT_DIR/e2e" >/dev/null || exit 1

  if ! command -v npx >/dev/null 2>&1; then
    echo "npx not found. Install Node.js/npm first."
    FAILURES=$((FAILURES + 1))
  else
    E2E_SPEC_ARRAY=()
    IFS=',' read -r -a RAW_E2E_SPECS <<< "$E2E_SPECS"
    for raw_spec in "${RAW_E2E_SPECS[@]}"; do
      spec="$(echo "$raw_spec" | xargs)"
      [[ -z "$spec" ]] && continue
      E2E_SPEC_ARRAY+=("$spec")
    done

    if [[ "$E2E_RANDOM_COUNT" -gt 0 && "${#E2E_SPEC_ARRAY[@]}" -gt "$E2E_RANDOM_COUNT" ]]; then
      echo "Randomly selecting $E2E_RANDOM_COUNT Playwright specs from ${#E2E_SPEC_ARRAY[@]} total..."
      # Shuffle and pick N
      E2E_SPEC_ARRAY=($(shuf -e "${E2E_SPEC_ARRAY[@]}" | head -n "$E2E_RANDOM_COUNT"))
    fi

    if [[ ${#E2E_SPEC_ARRAY[@]} -eq 0 ]]; then
      echo "No E2E specs configured. Set E2E_SPECS or --e2e-specs."
      FAILURES=$((FAILURES + 1))
    else
      E2E_SPEC_FAILURES=0
      for spec in "${E2E_SPEC_ARRAY[@]}"; do
        echo "Running E2E spec: $spec"
        E2E_CMD=(
          npx playwright test "$spec"
          --config="$E2E_CONFIG"
          --project="$E2E_PROJECT"
          --workers="$E2E_WORKERS"
        )
        if [[ "$E2E_FAIL_ON_FLAKY" == "true" ]]; then
          E2E_CMD+=(--fail-on-flaky-tests)
        fi
        set +e
        run_with_optional_timeout "$E2E_SPEC_TIMEOUT_SECONDS" "${E2E_CMD[@]}"
        E2E_STATUS=$?
        set -e
        if [[ $E2E_STATUS -ne 0 ]]; then
          echo "E2E spec FAILED: $spec"
          E2E_SPEC_FAILURES=$((E2E_SPEC_FAILURES + 1))
        else
          echo "E2E spec PASSED: $spec"
        fi
      done

      if [[ $E2E_SPEC_FAILURES -ne 0 ]]; then
        echo "Real Playwright E2E gate FAILED (${E2E_SPEC_FAILURES} spec(s) failed)."
        FAILURES=$((FAILURES + 1))
      else
        echo "Real Playwright E2E gate PASSED."

        section "Playwright Coverage Gate (threshold: ${PLAYWRIGHT_THRESHOLD}%)"
        PW_COV_TARGETS=()
        IFS=',' read -r -a RAW_PW_COV_TARGETS <<< "$PLAYWRIGHT_COVERAGE_TARGETS"
        for raw_cov_target in "${RAW_PW_COV_TARGETS[@]}"; do
          cov_target="$(echo "$raw_cov_target" | xargs)"
          [[ -z "$cov_target" ]] && continue
          if [[ -e "$cov_target" ]]; then
            PW_COV_TARGETS+=("$cov_target")
          else
            echo "Skipping missing Playwright coverage target: $cov_target"
          fi
        done

        PW_COV_INCLUDES=()
        IFS=',' read -r -a RAW_PW_COV_INCLUDES <<< "$PLAYWRIGHT_COVERAGE_INCLUDE"
        for raw_cov_include in "${RAW_PW_COV_INCLUDES[@]}"; do
          cov_include="$(echo "$raw_cov_include" | xargs)"
          [[ -z "$cov_include" ]] && continue
          PW_COV_INCLUDES+=("$cov_include")
        done

        if [[ ${#PW_COV_TARGETS[@]} -eq 0 ]]; then
          echo "No Playwright coverage targets found from PLAYWRIGHT_COVERAGE_TARGETS=$PLAYWRIGHT_COVERAGE_TARGETS"
          FAILURES=$((FAILURES + 1))
        elif [[ ${#PW_COV_INCLUDES[@]} -eq 0 ]]; then
          echo "No Playwright coverage include files configured from PLAYWRIGHT_COVERAGE_INCLUDE=$PLAYWRIGHT_COVERAGE_INCLUDE"
          FAILURES=$((FAILURES + 1))
        else
          rm -rf coverage-playwright
          PW_COV_CMD=(
            npx --yes c8
            --all
            --reporter=lcovonly
            --reporter=text-summary
            --report-dir=coverage-playwright
          )
          for cov_include in "${PW_COV_INCLUDES[@]}"; do
            PW_COV_CMD+=(--include="$cov_include")
          done
          PW_COV_CMD+=(
            npx playwright test
            "${PW_COV_TARGETS[@]}"
            --config="$E2E_CONFIG"
            --project="$E2E_PROJECT"
            --workers=1
            --fail-on-flaky-tests
          )

          echo "Running Playwright coverage targets: ${PW_COV_TARGETS[*]}"
          set +e
          run_with_optional_timeout "$PLAYWRIGHT_COVERAGE_TIMEOUT_SECONDS" "${PW_COV_CMD[@]}"
          PW_COV_STATUS=$?
          set -e

          if [[ $PW_COV_STATUS -ne 0 ]]; then
            echo "Playwright coverage targets FAILED."
            FAILURES=$((FAILURES + 1))
          else
            set +e
            check_playwright_threshold "$PLAYWRIGHT_THRESHOLD" "coverage-playwright/lcov.info"
            PW_THRESH_STATUS=$?
            set -e
            playwright_gap_report "coverage-playwright/lcov.info"
            if [[ $PW_THRESH_STATUS -ne 0 ]]; then
              echo "Playwright coverage gate FAILED."
              FAILURES=$((FAILURES + 1))
            else
              echo "Playwright coverage gate PASSED."
            fi
          fi
        fi
      fi
    fi
  fi

  popd >/dev/null || exit 1
fi

section "Quality Gate Summary"
if [[ $FAILURES -gt 0 ]]; then
  echo "FAILED with ${FAILURES} failing gate(s)."
  exit 1
fi

echo "PASSED. All enabled quality gates succeeded."
