#!/bin/bash

# Script pour démarrer tous les services nécessaires aux tests E2E
# Usage: ./scripts/start-e2e-services.sh

# Options:
#   --rebuild  : force flutter build web
#   --no-wait  : démarre les services et quitte (mode détaché)

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="/tmp/origna_e2e_logs"

NO_WAIT=false
for arg in "$@"; do
    if [ "$arg" == "--no-wait" ]; then
        NO_WAIT=true
    fi
done

# Créer le répertoire de logs
mkdir -p "$LOG_DIR"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  OrignaGTA E2E Services Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Fonction pour nettoyer les processus existants
cleanup() {
    echo -e "${YELLOW}🧹 Nettoyage des processus existants...${NC}"
    
    # Tuer les processus sur les ports utilisés
    lsof -ti :5005,8080,9099,5001,9199,4000 2>/dev/null | xargs kill -9 2>/dev/null || true
    
    # Tuer les processus Firebase et serve
    pkill -f "firebase.*emulator" 2>/dev/null || true
    pkill -f "npx serve" 2>/dev/null || true
    
    sleep 2
    echo -e "${GREEN}✓ Nettoyage terminé${NC}"
    echo ""
}

# Fonction pour vérifier si un port est libre
check_port() {
    local port=$1
    if lsof -ti :$port >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

# Fonction pour attendre qu'un port soit disponible
wait_for_port() {
    local port=$1
    local service=$2
    local max_wait=30
    local elapsed=0
    
    echo -n "  Attente de $service sur le port $port..."
    
    while [ $elapsed -lt $max_wait ]; do
        if lsof -ti :$port >/dev/null 2>&1; then
            echo -e " ${GREEN}OK${NC}"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        echo -n "."
    done
    
    echo -e " ${RED}TIMEOUT${NC}"
    return 1
}

# Nettoyer d'abord
cleanup

# Étape 1: Construire Flutter Web
echo -e "${BLUE}📦 Étape 1: Construction de Flutter Web${NC}"
cd "$PROJECT_DIR/origna_gta"

if [ ! -d "build/web" ] || [ "$1" == "--rebuild" ]; then
    echo "  Construction de l'application Flutter..."
    flutter build web --release > "$LOG_DIR/flutter_build.log" 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Build réussie${NC}"
    else
        echo -e "  ${RED}✗ Build échouée - voir $LOG_DIR/flutter_build.log${NC}"
        exit 1
    fi
else
    echo -e "  ${GREEN}✓ Build existante trouvée (utilisez --rebuild pour forcer)${NC}"
fi
echo ""

# Étape 2: Démarrer Firebase Emulators
echo -e "${BLUE}🔥 Étape 2: Démarrage des Firebase Emulators${NC}"
cd "$PROJECT_DIR"

echo "  Démarrage en arrière-plan..."
firebase emulators:start --only=auth,firestore,functions,storage > "$LOG_DIR/firebase.log" 2>&1 &
FIREBASE_PID=$!
echo "  PID: $FIREBASE_PID"

# Attendre que les émulateurs démarrent
sleep 5

# Vérifier les ports
if wait_for_port 9099 "Auth Emulator"; then
    if wait_for_port 8080 "Firestore Emulator"; then
        if wait_for_port 5001 "Functions Emulator"; then
            if wait_for_port 9199 "Storage Emulator"; then
                echo -e "  ${GREEN}✓ Tous les émulateurs Firebase sont démarrés${NC}"
                echo "  Logs: $LOG_DIR/firebase.log"
            else
                echo -e "  ${RED}✗ Storage Emulator n'a pas démarré${NC}"
                cat "$LOG_DIR/firebase.log"
                exit 1
            fi
        else
            echo -e "  ${RED}✗ Functions Emulator n'a pas démarré${NC}"
            exit 1
        fi
    else
        echo -e "  ${RED}✗ Firestore Emulator n'a pas démarré${NC}"
        exit 1
    fi
else
    echo -e "  ${RED}✗ Auth Emulator n'a pas démarré${NC}"
    exit 1
fi
echo ""

# Étape 3: Démarrer le serveur web
echo -e "${BLUE}🌐 Étape 3: Démarrage du serveur web${NC}"
cd "$PROJECT_DIR"

echo "  Démarrage de serve sur le port 5005..."
npx serve -s origna_gta/build/web -l 5005 > "$LOG_DIR/web_server.log" 2>&1 &
WEB_PID=$!
echo "  PID: $WEB_PID"

if wait_for_port 5005 "Web Server"; then
    echo -e "  ${GREEN}✓ Serveur web démarré${NC}"
    echo "  URL: http://localhost:5005"
    echo "  Logs: $LOG_DIR/web_server.log"
else
    echo -e "  ${RED}✗ Le serveur web n'a pas démarré${NC}"
    cat "$LOG_DIR/web_server.log"
    exit 1
fi
echo ""

# Étape 4: Démarrer le mock Stripe server
echo -e "${BLUE}💳 Étape 4: Démarrage du Mock Stripe Server${NC}"
cd "$PROJECT_DIR/functions"

echo "  Démarrage du mock Stripe sur le port 4242..."
python3 mock_stripe_server.py > "$LOG_DIR/mock_stripe.log" 2>&1 &
STRIPE_PID=$!
echo "  PID: $STRIPE_PID"

if wait_for_port 4242 "Mock Stripe Server"; then
    echo -e "  ${GREEN}✓ Mock Stripe démarré${NC}"
    echo "  URL: http://localhost:4242"
    echo "  Logs: $LOG_DIR/mock_stripe.log"
else
    echo -e "  ${RED}✗ Le mock Stripe n'a pas démarré${NC}"
    cat "$LOG_DIR/mock_stripe.log"
    exit 1
fi
echo ""

# Résumé
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  ✓ Tous les services sont prêts!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Services en cours d'exécution:${NC}"
echo ""
echo -e "  🔥 Firebase Emulators (PID: $FIREBASE_PID)"
echo "     - Auth:      http://localhost:9099"
echo "     - Firestore: http://localhost:8080"
echo "     - Functions: http://localhost:5001"
echo "     - Storage:   http://localhost:9199"
echo "     - UI:        http://localhost:4000"
echo ""
echo -e "  🌐 Web Server (PID: $WEB_PID)"
echo "     - App: http://localhost:5005"
echo ""
echo -e "  💳 Mock Stripe (PID: $STRIPE_PID)"
echo "     - API: http://localhost:4242"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "     - Firebase:  $LOG_DIR/firebase.log"
echo "     - Web:       $LOG_DIR/web_server.log"
echo "     - Flutter:   $LOG_DIR/flutter_build.log"
echo "     - Stripe:    $LOG_DIR/mock_stripe.log"
echo ""
echo -e "${YELLOW}Pour exécuter les tests:${NC}"
echo "     cd $PROJECT_DIR/e2e"
echo "     npx playwright test full-marketplace-e2e.spec.ts"
echo ""
echo -e "${YELLOW}Pour arrêter les services:${NC}"
echo "     kill $FIREBASE_PID $WEB_PID $STRIPE_PID"
echo "     ou: ./scripts/stop-e2e-services.sh"
echo ""

# Sauvegarder les PIDs pour le script d'arrêt
echo "$FIREBASE_PID" > "$LOG_DIR/firebase.pid"
echo "$WEB_PID" > "$LOG_DIR/web.pid"
echo "$STRIPE_PID" > "$LOG_DIR/stripe.pid"

if [ "$NO_WAIT" = true ]; then
    echo -e "${GREEN}Mode détaché activé (--no-wait).${NC}"
    echo -e "${YELLOW}Pour arrêter: ./scripts/stop-e2e-services.sh${NC}"
    exit 0
fi

# Attendre que l'utilisateur arrête
echo -e "${BLUE}Appuyez sur Ctrl+C pour arrêter tous les services${NC}"
echo ""

# Fonction de nettoyage en cas d'interruption
trap "echo ''; echo 'Arrêt des services...'; kill $FIREBASE_PID $WEB_PID $STRIPE_PID 2>/dev/null; rm -f $LOG_DIR/*.pid; echo 'Services arrêtés.'; exit 0" INT TERM

# Garder le script actif
wait
