#!/bin/bash
# =============================================================================
# Start All Emulator Services (Firebase + Stripe)
# =============================================================================
# This script starts:
# 1. Firebase Emulators (Auth, Firestore, Functions, Storage)
# 2. Stripe Webhook Forwarding to local functions
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Navigate to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 Starting All Emulator Services                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping all services...${NC}"
    pkill -f "firebase-tools" 2>/dev/null || true
    pkill -f "stripe listen" 2>/dev/null || true
    echo -e "${GREEN}✓ All services stopped${NC}"
}

trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    local missing=0
    
    if ! command -v firebase &> /dev/null; then
        echo -e "${RED}❌ Firebase CLI not found. Install: npm install -g firebase-tools${NC}"
        missing=1
    fi
    
    if ! command -v stripe &> /dev/null; then
        echo -e "${RED}❌ Stripe CLI not found. Install: brew install stripe/stripe-cli/stripe${NC}"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

check_prerequisites

# Load environment variables
if [ -f "functions/.env" ]; then
    echo -e "${GREEN}✓ Loading environment from functions/.env${NC}"
    export $(grep -v '^#' functions/.env | xargs)
fi

export FUNCTIONS_EMULATOR=true

# Create emulator-data directory
mkdir -p emulator-data

echo ""
echo -e "${CYAN}Starting Firebase Emulators...${NC}"
echo -e "  • Auth:      http://localhost:9099"
echo -e "  • Firestore: http://localhost:8080"
echo -e "  • Functions: http://localhost:5001"
echo -e "  • Storage:   http://localhost:9199"
echo -e "  • Hosting:   http://localhost:5000"
echo -e "  • UI:        http://localhost:4000"
echo ""

# Start Firebase emulators in background
firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data &
FIREBASE_PID=$!

# Wait for emulators to be ready
echo -e "${YELLOW}Waiting for Firebase emulators to start...${NC}"
for i in {1..60}; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Firebase emulators ready!${NC}"
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

if ! curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${RED}❌ Firebase emulators failed to start${NC}"
    exit 1
fi

# Start Stripe webhook forwarding
echo ""
echo -e "${CYAN}Starting Stripe Webhook Forwarding...${NC}"
echo -e "  • Forwarding to: localhost:5001/orignagta/us-central1/stripe_webhook"
echo ""

stripe listen --forward-to "localhost:5001/orignagta/us-central1/stripe_webhook" &
STRIPE_PID=$!

# Wait for Stripe to be ready
sleep 3

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ All services are running!                           ║${NC}"
echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║ Firebase UI:    http://localhost:4000                      ║${NC}"
echo -e "${GREEN}║ Functions:      http://localhost:5001                      ║${NC}"
echo -e "${GREEN}║ Stripe:         Webhooks forwarding active                 ║${NC}"
echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║ Press Ctrl+C to stop all services                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Keep script running
wait $FIREBASE_PID
