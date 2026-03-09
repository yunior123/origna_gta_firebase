#!/bin/bash
# =============================================================================
# Origna GTA Development Environment Startup Script
# Starts Firebase Emulators and Stripe Webhook Forwarding
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRIPE_WEBHOOK_URL="http://127.0.0.1:5001/orignagta/us-central1/stripe_webhook"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Origna GTA Development Environment                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    
    # Kill Stripe listener
    pkill -f "stripe listen" 2>/dev/null || true
    
    # Kill Firebase emulators
    pkill -f "firebase emulators" 2>/dev/null || true
    pkill -f "java.*firestore" 2>/dev/null || true
    
    # Clean up temp files
    rm -f /tmp/stripe-listen-*.log 2>/dev/null || true
    
    echo -e "${GREEN}✓ All services stopped${NC}"
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Kill any existing processes
echo -e "${YELLOW}Cleaning up existing processes...${NC}"
pkill -f "stripe listen" 2>/dev/null || true
pkill -f "firebase emulators" 2>/dev/null || true
pkill -f "java.*firestore" 2>/dev/null || true
sleep 2

# Check if ports are free
echo -e "${YELLOW}Checking ports...${NC}"
for port in 4000 5001 8080 9099 9199; do
    if lsof -i :$port >/dev/null 2>&1; then
        echo -e "${RED}Error: Port $port is still in use${NC}"
        lsof -i :$port | head -2
        exit 1
    fi
done
echo -e "${GREEN}✓ All ports are free${NC}"

# Start Firebase Emulators in background
echo -e "${YELLOW}Starting Firebase Emulators...${NC}"
cd "$PROJECT_DIR"
firebase emulators:start --only functions,firestore,auth,storage 2>&1 &
FIREBASE_PID=$!

# Wait for emulators to be ready
echo -e "${YELLOW}Waiting for emulators to start...${NC}"
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s http://127.0.0.1:4400/emulators >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Firebase Emulators are ready!${NC}"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    echo -n "."
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo -e "\n${RED}Error: Emulators failed to start within ${MAX_WAIT}s${NC}"
    exit 1
fi

# Start Stripe webhook forwarding and auto-inject webhook secret
echo -e "${YELLOW}Starting Stripe webhook forwarding...${NC}"

STRIPE_LOG="/tmp/stripe-listen-$$.log"
stripe listen --forward-to "$STRIPE_WEBHOOK_URL" \
  --events checkout.session.completed,checkout.session.async_payment_succeeded,checkout.session.async_payment_failed,checkout.session.expired,payment_intent.succeeded,payment_intent.payment_failed,payment_intent.canceled,charge.refunded,charge.dispute.created,charge.dispute.updated,charge.dispute.closed,charge.dispute.funds_reinstated,transfer.reversed,payout.failed,refund.failed,account.updated \
  > "$STRIPE_LOG" 2>&1 &
STRIPE_PID=$!

# Wait for Stripe to output the webhook signing secret
echo -e "${YELLOW}Waiting for Stripe CLI signing secret...${NC}"
STRIPE_WAIT=0
STRIPE_SECRET=""
while [ $STRIPE_WAIT -lt 15 ]; do
    if [ -f "$STRIPE_LOG" ]; then
        STRIPE_SECRET=$(grep -o 'whsec_[a-zA-Z0-9_]*' "$STRIPE_LOG" 2>/dev/null | head -1)
        if [ -n "$STRIPE_SECRET" ]; then
            break
        fi
    fi
    sleep 1
    STRIPE_WAIT=$((STRIPE_WAIT + 1))
done

# Auto-update .env with the new webhook secret
ENV_FILE="$PROJECT_DIR/functions/.env"
if [ -n "$STRIPE_SECRET" ]; then
    # Replace the webhook secret in .env
    if grep -q "^STRIPE_WEBHOOK_SECRET=" "$ENV_FILE" 2>/dev/null; then
        sed -i '' "s|^STRIPE_WEBHOOK_SECRET=.*|STRIPE_WEBHOOK_SECRET=$STRIPE_SECRET|" "$ENV_FILE"
        echo -e "${GREEN}✓ Auto-updated STRIPE_WEBHOOK_SECRET in functions/.env${NC}"
    else
        echo "STRIPE_WEBHOOK_SECRET=$STRIPE_SECRET" >> "$ENV_FILE"
        echo -e "${GREEN}✓ Added STRIPE_WEBHOOK_SECRET to functions/.env${NC}"
    fi
    echo -e "${GREEN}✓ Stripe webhook forwarding is active (secret: ${STRIPE_SECRET:0:15}...)${NC}"
else
    echo -e "${YELLOW}⚠️ Could not auto-detect webhook secret. Check $STRIPE_LOG${NC}"
fi

# Verify Stripe is running
if pgrep -f "stripe listen" >/dev/null; then
    echo -e "${GREEN}✓ Stripe webhook forwarding is active${NC}"
else
    echo -e "${RED}Error: Stripe webhook forwarding failed to start${NC}"
    echo -e "${YELLOW}Make sure you have Stripe CLI installed and logged in:${NC}"
    echo "  brew install stripe/stripe-cli/stripe"
    echo "  stripe login"
fi

# Display status
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Development Environment Ready!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo "  • Emulator UI:     http://127.0.0.1:4000/"
echo "  • Functions:       http://127.0.0.1:5001/"
echo "  • Firestore:       http://127.0.0.1:8080/"
echo "  • Auth:            http://127.0.0.1:9099/"
echo "  • Storage:         http://127.0.0.1:9199/"
echo ""
echo -e "${BLUE}Stripe Webhook:${NC}"
echo "  • Forwarding to:   $STRIPE_WEBHOOK_URL"
echo ""
echo -e "${YELLOW}⚠️  Webhook secret is auto-injected into functions/.env on each start.${NC}"
echo -e "${YELLOW}   No manual secret update needed.${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo ""

# Keep script running and show logs
wait $FIREBASE_PID
