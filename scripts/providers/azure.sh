# Azure-specific functions for scripts/deploy.sh and scripts/teardown.sh.
# Every provider file implements the same three functions and may set HELM_ARGS.

# AKS's "admissionsenforcer" rewrites namespaceSelectors of webhook configurations (e.g. cert-manager's).
# Helm 4 server-side apply then reports a field-manager conflict on every upgrade -> force our values.
HELM_ARGS=(--force-conflicts)

# Writes cluster credentials into ~/.kube/config
get_kube_credentials() {
  local cmd
  cmd=$(tf_output kube_credentials_command) # separate assignment so a failure stops the script
  eval "$cmd"
}

# Prints a secret value from the provider's secret store
get_secret() {
  az keyvault secret show --vault-name "$(tf_output secret_store_name)" --name "$1" --query value -o tsv
}

# Logs the local Docker client into the registry (manual image push)
registry_login() {
  local server
  server=$(tf_output registry_login_server)
  az acr login --name "${server%%.*}"
}
