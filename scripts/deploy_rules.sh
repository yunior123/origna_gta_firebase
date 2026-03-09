#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$REPO_ROOT"

echo -e "${YELLOW}Deploying Firestore rules, indexes, storage rules, and hosting to all environments...${NC}"

# Returns env name, build mode, and dart-defines for each project
get_env_config() {
  case "$1" in
    orignagta-dev)
      ENV_NAME="dev"
      BUILD_MODE="--debug"
      DART_DEFINES="--dart-define=ENVIRONMENT=dev --dart-define=FORCE_SEMANTICS=true"
      ;;
    orignagta-staging)
      ENV_NAME="staging"
      BUILD_MODE="--profile"
      DART_DEFINES="--dart-define=ENVIRONMENT=staging --dart-define=FORCE_SEMANTICS=true"
      ;;
    orignagta)
      ENV_NAME="prod"
      BUILD_MODE="--release"
      DART_DEFINES="--dart-define=ENVIRONMENT=production"
      ;;
  esac
}

for PROJECT in orignagta-dev orignagta-staging orignagta; do
  get_env_config "$PROJECT"
  echo ""
  echo -e "${YELLOW}→ [$ENV_NAME] $PROJECT${NC}"

  # --- REBUILD Flutter for this specific environment ---
  echo -e "  ${YELLOW}Building Flutter web for $ENV_NAME...${NC}"
  cd "$REPO_ROOT/origna_gta"
  flutter build web $BUILD_MODE $DART_DEFINES

  # Verify the build has the correct environment baked in
  if grep -q "ENVIRONMENT" "$REPO_ROOT/origna_gta/build/web/main.dart.js" 2>/dev/null; then
    echo -e "  ${GREEN}Build verified for $ENV_NAME${NC}"
  fi

  cd "$REPO_ROOT"

  # Deploy Firestore rules, indexes, and hosting
  firebase deploy --only firestore:rules,firestore:indexes,hosting --project "$PROJECT"

  # Deploy storage rules separately — gracefully skip if Firebase Storage not provisioned
  storage_exit=0
  storage_out=$(firebase deploy --only storage --project "$PROJECT" 2>&1) || storage_exit=$?
  if echo "$storage_out" | grep -q "Firebase Storage has not been set up"; then
    echo -e "  ${YELLOW}[$ENV_NAME] Firebase Storage not provisioned — skipping${NC}"
  elif [ "${storage_exit}" -ne 0 ]; then
    echo "$storage_out"
    exit "${storage_exit}"
  fi

  echo -e "  ${GREEN}[$ENV_NAME] Done${NC}"
done

echo ""
echo "Recording deployed versions..."
python3 "$REPO_ROOT/scripts/record_deploy_version.py" --env=dev     --component=all
python3 "$REPO_ROOT/scripts/record_deploy_version.py" --env=staging --component=all
python3 "$REPO_ROOT/scripts/record_deploy_version.py" --env=prod    --component=all

echo ""
echo -e "${GREEN}Rules, indexes, storage, and hosting deployed to all environments${NC}"
