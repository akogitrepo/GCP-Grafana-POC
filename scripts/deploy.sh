#!/usr/bin/env bash
# Push a freshly built image to both clusters. Useful from a developer laptop
# when iterating outside CI.
#
# Usage:  ./deploy.sh <app> <tag>
set -euo pipefail

APP="${1:?app required (web-app-a | web-app-b)}"
TAG="${2:?tag required (e.g. v1.0.1)}"
PROJECT="${PROJECT:-myorg-platform-prod}"
REPO="us-docker.pkg.dev/${PROJECT}/platform-images"

docker build -t "${REPO}/${APP}:${TAG}" "apps/${APP}"
docker push   "${REPO}/${APP}:${TAG}"

for ovr in primary secondary; do
  CLUSTER=$([ "$ovr" = "primary" ] && echo "gke-primary" || echo "gke-secondary")
  REGION=$([  "$ovr" = "primary" ] && echo "us-central1" || echo "us-east1")
  gcloud container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT"

  pushd "kubernetes/apps/${APP}/overlays/${ovr}" > /dev/null
  kubectl kustomize . | sed "s|:v1.0.0|:${TAG}|g" | kubectl apply -f -
  kubectl -n "$APP" rollout status "deploy/${APP}" --timeout=5m
  popd > /dev/null
done
