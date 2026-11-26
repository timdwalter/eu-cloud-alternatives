output "cluster_name" {
  value = module.infra.cluster_name
}

output "kube_credentials_command" {
  description = "Command that writes the cluster credentials to your kubeconfig."
  value       = module.infra.kube_credentials_command
}

output "registry_login_server" {
  value = module.infra.registry_login_server
}

output "db_host" {
  value = module.infra.db_host
}

output "db_user" {
  value = module.infra.db_user
}

output "secret_store_name" {
  description = "Where the DB password is stored (read by scripts/providers/<provider>.sh)."
  value       = module.infra.secret_store_name
}

output "ci_variables" {
  description = "Non-secret values to set as GitHub repository variables for the image pipeline."
  value       = module.infra.ci_variables
}
