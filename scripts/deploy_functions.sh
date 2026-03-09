#!/bin/bash
# Deploy Cloud Functions to all environments and record versions.
# Usage: ./scripts/deploy_functions.sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Deploying Cloud Functions to all environments...${NC}"

for PROJECT in orignagta-dev orignagta-staging orignagta; do
  ENV_NAME="${PROJECT##*-}"
  [[ "$PROJECT" == "orignagta" ]] && ENV_NAME="prod"
  echo ""
  echo "→ [$ENV_NAME] $PROJECT"
  firebase deploy --only functions --project "$PROJECT" --force
done

echo ""
echo -e "${YELLOW}Recording deployed versions...${NC}"
python3 "$REPO_ROOT/scripts/record_deploy_version.py" --env=dev     --component=functions
python3 "$REPO_ROOT/scripts/record_deploy_version.py" --env=staging --component=functions
python3 "$REPO_ROOT/scripts/record_deploy_version.py" --env=prod    --component=functions

echo ""
echo -e "${GREEN}✓ Functions deployed to all environments${NC}"
