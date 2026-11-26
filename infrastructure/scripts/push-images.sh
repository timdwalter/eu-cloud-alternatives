#!/usr/bin/env bash
# Manual image build and push (the GitHub Actions pipeline does the same on every push to main).
# Usage: infrastructure/scripts/push-images.sh <provider> [tag]   – tag defaults to the current git short SHA
source "$(dirname "$0")/lib.sh"

TAG="${2:-$(git -C "$ROOT" rev-parse --short HEAD)}"
REGISTRY=$(tf_output registry_login_server)

registry_login
for svc in backend frontend; do
  log "textlib-$svc:$TAG"
  docker build --platform linux/amd64 -t "$REGISTRY/textlib-$svc:$TAG" "$ROOT/apps/$svc"
  docker push "$REGISTRY/textlib-$svc:$TAG"
done
echo
echo "Pushed tag $TAG – set IMAGE_TAG=$TAG in infrastructure/platform/config.local.env and run infrastructure/scripts/deploy.sh $PROVIDER"
