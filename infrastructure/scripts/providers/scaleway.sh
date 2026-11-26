# Scaleway-specific functions for deploy.sh / teardown.sh / push-images.sh.
# Same three functions as providers/azure.sh, plus provider_pre_deploy (pull secret).

# CLI name: "scw" (Homebrew, docs) or "scaleway-cli" (winget on Windows)
SCW_BIN=$(command -v scw || command -v scaleway-cli || true)
[[ -n "$SCW_BIN" ]] || { echo "Scaleway CLI not found (scw / scaleway-cli)" >&2; exit 1; }
# Project-scoped profile used by Terraform as well
export SCW_PROFILE="${SCW_PROFILE:-textlib-terraform}"
REGISTRY_HOST="rg.fr-par.scw.cloud"

# Writes cluster credentials into ~/.kube/config
get_kube_credentials() {
  local cmd
  cmd=$(tf_output kube_credentials_command)
  "$SCW_BIN" ${cmd#scw }
}

# Prints the latest version of a Secret Manager secret by name
get_secret() {
  "$SCW_BIN" secret version access-by-path secret-name="$1" revision=latest_enabled -o json \
    | sed -n 's/.*"data": *"\([^"]*\)".*/\1/p' | base64 -d
}

# Logs the local Docker client into the registry (manual image push)
registry_login() {
  "$SCW_BIN" config get secret-key | docker login "$REGISTRY_HOST" -u nologin --password-stdin
}

# Kapsule has no keyless pull from a private registry: create a pull secret from a read-only key
# (stored in Secret Manager as "registry-pull-key") and attach it to the namespace's default
# ServiceAccount, so the chart needs no change.
provider_pre_deploy() {
  local key
  key=$(get_secret registry-pull-key)
  kubectl -n "$NAMESPACE" create secret docker-registry scw-registry \
    --docker-server="$REGISTRY_HOST" --docker-username=nologin --docker-password="$key" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$NAMESPACE" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"scw-registry"}]}' >/dev/null
  echo "pull secret scw-registry ok (value not printed)"
}
