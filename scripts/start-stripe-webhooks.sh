#!/bin/bash
# =============================================================================
# Start Stripe Webhook Forwarding to Local Emulator
# =============================================================================
# This script forwards Stripe webhook events to your local Firebase Functions
# emulator for testing payment flows.
#
# PREREQUISITES:
# 1. Install Stripe CLI: brew install stripe/stripe-cli/stripe
# 2. Login to Stripe: stripe login
# 3. Have Firebase emulators running
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEBHOOK_ENDPOINT="localhost:5001/orignagta/us-central1/stripe_webhook"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     💳 Stripe Webhook Forwarding - Emulator Mode          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Check if Stripe CLI is installed
if ! command -v stripe &> /dev/null; then
    echo -e "${RED}❌ Stripe CLI not found.${NC}"
    echo -e "   Install with: ${YELLOW}brew install stripe/stripe-cli/stripe${NC}"
    echo -e "   Then login:   ${YELLOW}stripe login${NC}"
    exit 1
fi

# Check if Firebase emulators are running
check_emulator_running() {
    if curl -s http://localhost:5001 > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

if ! check_emulator_running; then
    echo -e "${YELLOW}⚠️  Firebase Functions emulator not detected at localhost:5001${NC}"
    echo -e "   Make sure to run: ${YELLOW}firebase emulators:start${NC}"
    echo -e ""
    echo -e "   Starting Stripe listener anyway..."
fi

echo ""
echo -e "${GREEN}Forwarding webhooks to: ${WEBHOOK_ENDPOINT}${NC}"
echo ""
echo -e "${YELLOW}TIP: Copy the webhook signing secret (whsec_...) and add it to your .env file:${NC}"
echo -e "     ${BLUE}STRIPE_WEBHOOK_SECRET=whsec_xxxxx${NC}"
echo ""

# Start Stripe listener
stripe listen --forward-to "${WEBHOOK_ENDPOINT}" --print-secret
