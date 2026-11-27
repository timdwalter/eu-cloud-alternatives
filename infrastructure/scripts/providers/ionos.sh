# IONOS-specific functions for deploy.sh / teardown.sh / push-images.sh.
# Same three functions as providers/azure.sh, plus provider_pre_deploy (pull secret, second database).
# Credentials: ionosctl uses the token from its config (ionosctl login --token …) or IONOS_TOKEN.

IONOSCTL=$(command -v ionosctl || true)
[[ -n "$IONOSCTL" ]] || { echo "ionosctl not found" >&2; exit 1; }
PG_CLIENT_IMAGE="postgres:17.6-alpine"

# Writes the cluster credentials into ~/.kube/config (merged, other contexts are kept)
get_kube_credentials() {
  local cmd new main sep
  cmd=$(tf_output kube_credentials_command)
  mkdir -p "$HOME/.kube"
  touch "$HOME/.kube/config"
  new="$HOME/.kube/ionos-textlib.yaml"
  main="$HOME/.kube/config"
  sep=":"
  # Git Bash on Windows: kubectl.exe expects Windows paths and ";" as the KUBECONFIG separator
  if command -v cygpath >/dev/null; then new=$(cygpath -w "$new"); main=$(cygpath -w "$main"); sep=";"; fi
  "$IONOSCTL" ${cmd#ionosctl } > "$new"
  KUBECONFIG="$new$sep$main" kubectl config view --flatten > "$main.merged"
  mv "$main.merged" "$main"
  kubectl config use-context "$(KUBECONFIG="$new" kubectl config current-context)" >/dev/null
  rm -f "$new"
}

# No secret store on IONOS: secrets come from the local (gitignored) Terraform state
get_secret() {
  case "$1" in
    db-password) terraform -chdir="$TF_DIR" output -raw db_password ;;
    *) echo "unknown secret: $1" >&2; return 1 ;;
  esac
}

# Logs the local Docker client into the registry (manual image push) with the CI token
registry_login() {
  local user
  user=$(terraform -chdir="$TF_DIR" output -json ci_variables | sed -n 's/.*"REGISTRY_USERNAME": *"\([^"]*\)".*/\1/p')
  terraform -chdir="$TF_DIR" output -raw registry_ci_password |
    docker login "$(tf_output registry_login_server)" -u "$user" --password-stdin
}

provider_pre_deploy() {
  # 1) No keyless pull: pull secret from the pull-only registry token, attached to the default
  #    ServiceAccount of the namespace (no chart change).
  kubectl -n "$NAMESPACE" create secret docker-registry ionos-registry \
    --docker-server="$(tf_output registry_login_server)" \
    --docker-username="$(tf_output registry_pull_user)" \
    --docker-password="$(terraform -chdir="$TF_DIR" output -raw registry_pull_password)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$NAMESPACE" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"ionos-registry"}]}' >/dev/null
  echo "pull secret ionos-registry ok (value not printed)"

  # 2) DBaaS PostgreSQL v2 creates only the initial database "app": create "keycloak" if missing.
  #    Runs inside the cluster (the DB is only reachable from the private LAN) and verifies the
  #    server certificate (sslmode=verify-full against the system CAs). Password from the cluster secret.
  local host user
  host=$(tf_output db_host)
  user=$(tf_output db_user)
  kubectl -n "$NAMESPACE" delete pod pg-init --ignore-not-found >/dev/null
  kubectl -n "$NAMESPACE" run pg-init --rm -i --restart=Never --image="$PG_CLIENT_IMAGE" \
    --overrides='{"spec":{"containers":[{"name":"pg-init","image":"'"$PG_CLIENT_IMAGE"'",
      "env":[{"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"textlib-secrets","key":"db-password"}}}],
      "command":["sh","-c","c=\"host='"$host"' dbname=app user='"$user"' sslmode=verify-full sslrootcert=system\"; psql \"$c\" -tAc \"SELECT datname FROM pg_database\" | grep -qx keycloak && echo \"database keycloak exists\" || psql \"$c\" -c \"CREATE DATABASE keycloak\""]}]}}' \
    2>&1 | grep -v -E "^pod .* deleted|If you don't see a command prompt"
}
