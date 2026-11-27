# OVHcloud-specific functions for deploy.sh / teardown.sh / push-images.sh.
# Same three functions as providers/azure.sh, plus provider_pre_deploy (pull secret).
# Credentials: OVH_CLIENT_ID / OVH_CLIENT_SECRET of the service account textlib-terraform (also used by Terraform).

OVH_API="https://eu.api.ovh.com"
OVH_TOKEN_URL="https://www.ovh.com/auth/oauth2/token"

# Writes the cluster credentials from the Terraform state into ~/.kube/config (merged, other contexts kept)
get_kube_credentials() {
  local new main sep
  mkdir -p "$HOME/.kube"
  touch "$HOME/.kube/config"
  new="$HOME/.kube/ovhcloud-textlib.yaml"
  main="$HOME/.kube/config"
  sep=":"
  # Git Bash on Windows: kubectl.exe expects Windows paths and ";" as the KUBECONFIG separator
  if command -v cygpath >/dev/null; then new=$(cygpath -w "$new"); main=$(cygpath -w "$main"); sep=";"; fi
  terraform -chdir="$TF_DIR" output -raw kubeconfig > "$new"
  KUBECONFIG="$new$sep$main" kubectl config view --flatten > "$main.merged"
  mv "$main.merged" "$main"
  kubectl config use-context "$(KUBECONFIG="$new" kubectl config current-context)" >/dev/null
  rm -f "$new"
}

# Short-lived OAuth2 access token of the service account
ovh_token() {
  : "${OVH_CLIENT_ID:?set OVH_CLIENT_ID}" "${OVH_CLIENT_SECRET:?set OVH_CLIENT_SECRET}"
  curl -sf -X POST "$OVH_TOKEN_URL" \
    --data-urlencode grant_type=client_credentials \
    --data-urlencode "client_id=$OVH_CLIENT_ID" \
    --data-urlencode "client_secret=$OVH_CLIENT_SECRET" \
    --data-urlencode scope=all | sed -n 's/.*"access_token": *"\([^"]*\)".*/\1/p'
}

# Prints a secret from Secret Manager (OKMS). secret_store_name = "<okms id>/<path prefix>/db-password"
get_secret() {
  case "$1" in
    db-password) ;;
    *) echo "unknown secret: $1" >&2; return 1 ;;
  esac
  local ref okms path
  ref=$(tf_output secret_store_name)
  okms=${ref%%/*}
  path=${ref#*/}
  curl -sf -H "Authorization: Bearer $(ovh_token)" \
    "$OVH_API/v2/okms/resource/$okms/secret/$path?includeData=true" |
    sed -n 's/.*\\\?"password\\\?": *\\\?"\([^"\\]*\)\\\?".*/\1/p'
}

# Logs the local Docker client into the registry (manual image push) with the CI user
registry_login() {
  local user
  user=$(terraform -chdir="$TF_DIR" output -json ci_variables | sed -n 's/.*"REGISTRY_USERNAME": *"\([^"]*\)".*/\1/p')
  terraform -chdir="$TF_DIR" output -raw registry_ci_password |
    docker login "$(tf_output registry_login_server)" -u "$user" --password-stdin
}

# No keyless pull: pull secret from the registry's pull user, attached to the namespace's default
# ServiceAccount (no chart change).
provider_pre_deploy() {
  kubectl -n "$NAMESPACE" create secret docker-registry ovh-registry \
    --docker-server="$(tf_output registry_login_server)" \
    --docker-username="$(tf_output registry_pull_user)" \
    --docker-password="$(terraform -chdir="$TF_DIR" output -raw registry_pull_password)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$NAMESPACE" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"ovh-registry"}]}' >/dev/null
  echo "pull secret ovh-registry ok (value not printed)"
}
