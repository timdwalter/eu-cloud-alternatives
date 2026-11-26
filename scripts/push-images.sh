#!/usr/bin/env bash
# Manual image build and push (the GitHub Actions pipeline does the same on every push to main).
# Usage: scripts/push-images.sh <provider> [tag]   – tag defaults to the current git short SHA
source "$(dirname "$0")/lib.sh"

TAG="${2:-$(git -C "$ROOT" rev-parse --short HEAD)}"
REGISTRY=$(tf_output registry_login_server)

registry_login
for svc in backend frontend; do
  log "textlib-$svc:$TAG"
  docker build --platform linux/amd64 -t "$REGISTRY/textlib-$svc:$TAG" "$ROOT/app/$svc"
  docker push "$REGISTRY/textlib-$svc:$TAG"
done
echo
echo "Pushed tag $TAG – set IMAGE_TAG=$TAG in platform/config.local.env and run scripts/deploy.sh $PROVIDER"
