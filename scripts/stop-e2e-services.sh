#!/bin/bash

# Script pour arrêter tous les services E2E
# Usage: ./scripts/stop-e2e-services.sh

LOG_DIR="/tmp/origna_e2e_logs"

echo "Arrêt des services E2E..."

# Lire les PIDs sauvegardés
if [ -f "$LOG_DIR/firebase.pid" ]; then
    FIREBASE_PID=$(cat "$LOG_DIR/firebase.pid")
    echo "Arrêt Firebase Emulators (PID: $FIREBASE_PID)..."
    kill $FIREBASE_PID 2>/dev/null || true
    rm -f "$LOG_DIR/firebase.pid"
fi

if [ -f "$LOG_DIR/web.pid" ]; then
    WEB_PID=$(cat "$LOG_DIR/web.pid")
    echo "Arrêt Web Server (PID: $WEB_PID)..."
    kill $WEB_PID 2>/dev/null || true
    rm -f "$LOG_DIR/web.pid"
fi

if [ -f "$LOG_DIR/stripe.pid" ]; then
    STRIPE_PID=$(cat "$LOG_DIR/stripe.pid")
    echo "Arrêt Mock Stripe Server (PID: $STRIPE_PID)..."
    kill $STRIPE_PID 2>/dev/null || true
    rm -f "$LOG_DIR/stripe.pid"
fi

# Nettoyage des ports
echo "Libération des ports..."
lsof -ti :5005,8080,9099,5001,9199,4000,4242 2>/dev/null | xargs kill -9 2>/dev/null || true

# Nettoyage des processus par nom
pkill -f "firebase.*emulator" 2>/dev/null || true
pkill -f "npx serve" 2>/dev/null || true
pkill -f "mock_stripe_server" 2>/dev/null || true

echo "✓ Tous les services ont été arrêtés"
