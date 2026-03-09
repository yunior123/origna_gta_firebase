#!/bin/bash
# run-playwright-e2e.sh - Dedicated Playwright E2E test runner
# This script runs Playwright E2E tests with optional service management
#
# Usage: ./scripts/run-playwright-e2e.sh [OPTIONS] [TEST_SUITE]
#
# Arguments:
#   TEST_SUITE          Test suite to run: flutter|smoke|all (default: all)
#
# Options:
#   --with-services     Start E2E services before running tests and stop after
#   --rebuild           Force Flutter web rebuild when using --with-services
#   --ui                Run Playwright in UI mode
#   --workers=N         Override number of Playwright workers
#   --project=NAME      Override Playwright project (default: chromium)
#   --help, -h          Show this help message
#
# Examples:
#   ./scripts/run-playwright-e2e.sh                    # Run all tests (services must be running)
#   ./scripts/run-playwright-e2e.sh flutter            # Run Flutter Web E2E tests only
#   ./scripts/run-playwright-e2e.sh --with-services    # Start services, run all tests, stop services
#   ./scripts/run-playwright-e2e.sh --with-services --rebuild smoke
#   ./scripts/run-playwright-e2e.sh --ui               # Run with Playwright UI

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
WITH_SERVICES=false
REBUILD=false
UI_MODE=false
TEST_SUITE="all"
WORKERS=""
PROJECT="chromium"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --with-services)
            WITH_SERVICES=true
            shift
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        --ui)
            UI_MODE=true
            shift
            ;;
        --workers=*)
            WORKERS="${arg#*=}"
            shift
            ;;
        --project=*)
            PROJECT="${arg#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [TEST_SUITE]"
            echo ""
            echo "Arguments:"
            echo "  TEST_SUITE          Test suite to run: flutter|smoke|all (default: all)"
            echo ""
            echo "Options:"
            echo "  --with-services     Start E2E services before running tests and stop after"
            echo "  --rebuild           Force Flutter web rebuild when using --with-services"
            echo "  --ui                Run Playwright in UI mode"
            echo "  --workers=N         Override number of Playwright workers"
            echo "  --project=NAME      Override Playwright project (default: chromium)"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run all tests (services must be running)"
            echo "  $0 flutter                            # Run Flutter Web E2E tests only"
            echo "  $0 --with-services                    # Start services, run all tests, stop services"
            echo "  $0 --with-services --rebuild smoke    # Full setup with rebuild, run smoke tests"
            echo "  $0 --ui                               # Run with Playwright UI mode"
            exit 0
            ;;
        flutter|-f)
            TEST_SUITE="flutter"
            shift
            ;;
        smoke|-s)
            TEST_SUITE="smoke"
            shift
            ;;
        all|-a)
            TEST_SUITE="all"
            shift
            ;;
        *)
            # Unknown option or test file
            if [[ "$arg" == *.spec.ts ]]; then
                TEST_SUITE="$arg"
            elif [[ "$arg" != "" ]]; then
                echo -e "${RED}Unknown option: $arg${NC}"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Playwright E2E Test Runner${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Resolve test files based on suite
resolve_test_files() {
    case "$TEST_SUITE" in
        flutter|-f)
            echo "flutter-web-e2e.spec.ts"
            ;;
        smoke|-s)
            echo "full-marketplace-e2e.spec.ts"
            ;;
        all|-a)
            echo "flutter-web-e2e.spec.ts full-marketplace-e2e.spec.ts"
            ;;
        *.spec.ts)
            echo "$TEST_SUITE"
            ;;
        *)
            echo -e "${RED}Unknown test suite: $TEST_SUITE${NC}"
            exit 1
            ;;
    esac
}

# Check if E2E services are running
check_services() {
    local all_ok=true
    
    echo -e "📡 Checking E2E services..."
    
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
        return 1
    fi
    
    echo -e "${GREEN}All services running!${NC}"
    return 0
}

# Start E2E services
start_services() {
    echo -e "${YELLOW}Starting E2E services...${NC}"
    
    local rebuild_flag=""
    if [ "$REBUILD" = true ]; then
        rebuild_flag="--rebuild"
    fi
    
    "$SCRIPT_DIR/start-e2e-services.sh" $rebuild_flag --no-wait
    
    # Give services a moment to fully initialize
    sleep 3
    
    echo ""
}

# Stop E2E services
stop_services() {
    echo -e "${YELLOW}Stopping E2E services...${NC}"
    "$SCRIPT_DIR/stop-e2e-services.sh"
    echo ""
}

# Run Playwright tests
run_tests() {
    local test_files=$(resolve_test_files)
    
    echo -e "${BLUE}Running Playwright E2E Tests${NC}"
    echo -e "Test suite: ${YELLOW}$TEST_SUITE${NC}"
    echo -e "Test files: ${YELLOW}$test_files${NC}"
    echo ""
    
    cd "$PROJECT_DIR/e2e"
    
    # Build command
    local cmd="npx playwright test"
    
    if [ "$UI_MODE" = true ]; then
        cmd="$cmd $test_files --ui"
    else
        cmd="$cmd $test_files --project=$PROJECT --reporter=list"
        
        if [ -n "$WORKERS" ]; then
            cmd="$cmd --workers=$WORKERS"
        fi
    fi
    
    echo -e "${BLUE}Executing: $cmd${NC}"
    echo ""
    
    if eval $cmd; then
        echo ""
        echo -e "${GREEN}✅ Playwright E2E tests passed!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}❌ Playwright E2E tests failed!${NC}"
        return 1
    fi
}

# Cleanup function for trap
cleanup() {
    if [ "$WITH_SERVICES" = true ]; then
        echo ""
        stop_services
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT INT TERM

# Main execution
echo -e "Configuration:"
echo -e "  Test suite:    ${YELLOW}$TEST_SUITE${NC}"
echo -e "  With services: ${YELLOW}$WITH_SERVICES${NC}"
echo -e "  Rebuild:       ${YELLOW}$REBUILD${NC}"
echo -e "  UI mode:       ${YELLOW}$UI_MODE${NC}"
if [ -n "$WORKERS" ]; then
    echo -e "  Workers:       ${YELLOW}$WORKERS${NC}"
fi
echo -e "  Project:       ${YELLOW}$PROJECT${NC}"
echo ""

# Start services if requested
if [ "$WITH_SERVICES" = true ]; then
    start_services
fi

# Check services are running
check_services || {
    echo ""
    echo -e "${RED}E2E services are not running.${NC}"
    echo "Start services manually with:"
    echo "  ./scripts/start-e2e-services.sh"
    echo ""
    echo "Or use --with-services flag to start them automatically:"
    echo "  $0 --with-services $TEST_SUITE"
    exit 1
}

echo ""

# Run tests
run_tests
