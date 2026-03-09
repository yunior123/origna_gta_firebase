#!/bin/bash
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Remote CI/Codemagic are the default path for heavy deploy/test work.
# Local pre-push deploys stay opt-in to protect low-RAM developer machines.
if [ "${RUN_PRE_PUSH_DEPLOY:-0}" = "1" ]; then
  "$REPO_ROOT/scripts/deploy_rules.sh"
else
  echo "Skipping local deploy_rules.sh (set RUN_PRE_PUSH_DEPLOY=1 to force it)."
fi

"$REPO_ROOT/scripts/pre_push_validation.sh"
