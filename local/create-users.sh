#!/usr/bin/env bash
# Creates the local test users in Keycloak (values from local/.env):
#   EDITOR_USERNAME – has the realm role "editor"
#   READER_USERNAME – no role, used to check that writes are rejected
# Safe to run again: existing users only get their password reset.
set -euo pipefail
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1 # Git Bash on Windows: do not rewrite container paths

set -a
# shellcheck disable=SC1091
source .env
set +a

kc() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@"; }

kc config credentials --server http://localhost:8080 --realm master \
  --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASSWORD" >/dev/null

create_user() {
  local user=$1 pass=$2
  kc create users -r "$REALM_NAME" -s username="$user" -s enabled=true \
    -s email="$user@example.com" -s emailVerified=true \
    -s firstName="$user" -s lastName="User" >/dev/null 2>&1 || echo "user $user exists"
  kc set-password -r "$REALM_NAME" --username "$user" --new-password "$pass"
}

create_user "$EDITOR_USERNAME" "$EDITOR_PASSWORD"
kc add-roles -r "$REALM_NAME" --uusername "$EDITOR_USERNAME" --rolename editor
create_user "$READER_USERNAME" "$READER_PASSWORD"

echo "Users ready: $EDITOR_USERNAME (editor), $READER_USERNAME (no role)"
