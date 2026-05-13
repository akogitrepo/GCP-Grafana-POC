#!/usr/bin/env bash
# One-time bootstrap to create the Terraform state bucket and configure
# Workload Identity Federation for GitHub Actions.
#
# Usage:  ./bootstrap.sh <state-bucket-name> <gcp-project-for-state>
set -euo pipefail

BUCKET="${1:?bucket name required}"
PROJECT="${2:?gcp project required}"
LOCATION="${3:-US}"

gcloud config set project "$PROJECT"

# 1. State bucket
gcloud storage buckets create "gs://${BUCKET}" \
  --location="$LOCATION" \
  --uniform-bucket-level-access \
  --default-storage-class=STANDARD || true

gcloud storage buckets update "gs://${BUCKET}" \
  --versioning \
  --soft-delete-duration=7d

# 2. (Optional) Workload Identity Federation pool + provider for GitHub
POOL="github-actions"
PROVIDER="github"
SA_NAME="cicd-deployer"

gcloud iam workload-identity-pools create "$POOL" \
  --location=global \
  --display-name="GitHub Actions" || true

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --location=global \
  --workload-identity-pool="$POOL" \
  --display-name="GitHub OIDC" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --issuer-uri="https://token.actions.githubusercontent.com" || true

echo
echo "Bucket:        gs://${BUCKET}"
echo "WIF provider:  projects/$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}"
echo
echo "Set these in your GitHub repo:"
echo "  vars.GCP_PROJECT_ID = <env project>"
echo "  vars.WIF_PROVIDER    = <printed above>"
echo "  vars.WIF_DEPLOYER_SA = ${SA_NAME}@<env-project>.iam.gserviceaccount.com"
