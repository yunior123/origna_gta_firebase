#!/usr/bin/env bash
# setup_backup_buckets.sh — One-time GCS bucket creation for Firestore daily backups
# Run once per environment before deploying the backup_firestore Cloud Function.
#
# Prerequisites:
#   gcloud auth login
#   gcloud config set project <PROJECT_ID>
#
# Usage:
#   bash scripts/setup_backup_buckets.sh dev
#   bash scripts/setup_backup_buckets.sh staging
#   bash scripts/setup_backup_buckets.sh prod
#
# What this does:
#   1. Creates a regional GCS bucket (northamerica-northeast1 = Toronto)
#   2. Grants the App Engine service account import/export admin + object admin
#   3. Sets a 90-day lifecycle policy (older backups auto-deleted)

set -euo pipefail

REGION="northamerica-northeast1"
LIFECYCLE_DAYS=90

case "${1:-}" in
  dev)
    PROJECT="orignagta-dev"
    BUCKET="orignagta-dev-backups"
    ;;
  staging)
    PROJECT="orignagta-staging"
    BUCKET="orignagta-staging-backups"
    ;;
  prod)
    PROJECT="orignagta"
    BUCKET="orignagta-backups"
    ;;
  *)
    echo "Usage: $0 <dev|staging|prod>"
    exit 1
    ;;
esac

SA="${PROJECT}@appspot.gserviceaccount.com"

echo "=== Setting up Firestore backup bucket for ${PROJECT} ==="

# 1. Create bucket (skip if already exists)
if gsutil ls "gs://${BUCKET}" &>/dev/null; then
  echo "Bucket gs://${BUCKET} already exists — skipping creation"
else
  gsutil mb \
    -p "${PROJECT}" \
    -l "${REGION}" \
    -b on \
    "gs://${BUCKET}"
  echo "Created gs://${BUCKET}"
fi

# 2. Grant Cloud Functions SA Firestore import/export admin
gcloud projects add-iam-policy-binding "${PROJECT}" \
  --member="serviceAccount:${SA}" \
  --role="roles/datastore.importExportAdmin" \
  --condition=None \
  --quiet
echo "Granted roles/datastore.importExportAdmin to ${SA}"

# 3. Grant SA object admin on the bucket
gsutil iam ch \
  "serviceAccount:${SA}:roles/storage.objectAdmin" \
  "gs://${BUCKET}"
echo "Granted roles/storage.objectAdmin on gs://${BUCKET}"

# 4. Apply 90-day lifecycle (auto-delete old backups)
TMP=$(mktemp /tmp/lifecycle-XXXXXX.json)
cat >"${TMP}" <<EOF
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": ${LIFECYCLE_DAYS}}
    }
  ]
}
EOF
gsutil lifecycle set "${TMP}" "gs://${BUCKET}"
rm -f "${TMP}"
echo "Set ${LIFECYCLE_DAYS}-day lifecycle on gs://${BUCKET}"

echo ""
echo "=== Done! Daily backup will run at 02:00 UTC via backup_firestore Cloud Function ==="
echo "Monitor: https://console.cloud.google.com/storage/browser/${BUCKET}"
