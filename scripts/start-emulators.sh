#!/bin/bash
# =============================================================================
# Start Firebase Emulators with data persistence
# =============================================================================
# This script starts all Firebase emulators with:
# - Data import from ./emulator-data (if exists)
# - Data export on exit to ./emulator-data
# - All services: Auth, Firestore, Functions, Storage, Hosting
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🔥 Firebase Emulators - Micro Staging Environment     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Check if firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found. Install with: npm install -g firebase-tools${NC}"
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")/.."

# Load environment variables from .env if exists
if [ -f "functions/.env" ]; then
    echo -e "${GREEN}✓ Loading environment from functions/.env${NC}"
    export $(grep -v '^#' functions/.env | xargs)
fi

# Set emulator environment
export FUNCTIONS_EMULATOR=true

# Create emulator-data directory if it doesn't exist
mkdir -p emulator-data

echo -e "${YELLOW}Starting emulators...${NC}"
echo -e "  • Auth:      http://localhost:9099"
echo -e "  • Firestore: http://localhost:8080"
echo -e "  • Functions: http://localhost:5001"
echo -e "  • Storage:   http://localhost:9199"
echo -e "  • Hosting:   http://localhost:5000"
echo -e "  • UI:        http://localhost:4000"
echo ""

# Check if emulator data exists
if [ -d "emulator-data" ] && [ "$(ls -A emulator-data 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Importing existing emulator data from ./emulator-data${NC}"
    firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
else
    echo -e "${YELLOW}⚠ No existing emulator data found. Starting fresh.${NC}"
    firebase emulators:start --export-on-exit=./emulator-data
fi
