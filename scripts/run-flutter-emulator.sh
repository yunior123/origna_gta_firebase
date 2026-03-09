#!/bin/bash
# =============================================================================
# Run Flutter in Emulator Mode
# =============================================================================
# This script:
# 1. Starts Firebase emulators in background (if not running)
# 2. Launches Flutter with emulator configuration
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEVICE="${1:-chrome}"
MODE="${2:-debug}"  # debug or release

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 Flutter + Firebase Emulator Launcher               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Device: ${GREEN}$DEVICE${NC}"
echo -e "Mode:   ${GREEN}$MODE${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if emulators are already running
check_emulator_running() {
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Start emulators if not running
if check_emulator_running; then
    echo -e "${GREEN}✓ Firebase emulators already running${NC}"
else
    echo -e "${YELLOW}Starting Firebase emulators in background...${NC}"
    
    # Start emulators in background
    ./scripts/start-emulators.sh &
    EMULATOR_PID=$!
    
    # Wait for emulators to be ready
    echo -e "Waiting for emulators to start..."
    for i in {1..30}; do
        if check_emulator_running; then
            echo -e "${GREEN}✓ Emulators ready!${NC}"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""
    
    if ! check_emulator_running; then
        echo -e "${RED}❌ Emulators failed to start${NC}"
        exit 1
    fi
fi

# Navigate to Flutter project
cd origna_gta

echo -e "${BLUE}Launching Flutter...${NC}"

# Build flutter args
FLUTTER_ARGS=(
    "run"
    "-d" "$DEVICE"
    "--dart-define=ENVIRONMENT=emulator"
    "--dart-define=USE_EMULATORS=true"
)

if [ "$MODE" = "release" ]; then
    FLUTTER_ARGS+=("--release")
fi

# Run Flutter
flutter "${FLUTTER_ARGS[@]}"
