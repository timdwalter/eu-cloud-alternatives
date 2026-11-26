# Provider module interface – identical outputs for every provider module.

output "cluster_name" {
  value = scaleway_k8s_cluster.this.name
}

output "kube_credentials_command" {
  # "scw" is the CLI name in the docs; on Windows (winget) the binary is "scaleway-cli" – the provider
  # script replaces it.
  value = "scw k8s kubeconfig install ${split("/", scaleway_k8s_cluster.this.id)[1]} region=${var.region}"
}

output "registry_login_server" {
  value = scaleway_registry_namespace.this.endpoint
}

output "db_host" {
  value = scaleway_rdb_instance.this.private_network[0].ip
}

output "db_user" {
  value = scaleway_rdb_instance.this.user_name
}

output "secret_store_name" {
  value = scaleway_secret.db_password.name
}

output "ci_variables" {
  value = {
    REGISTRY = scaleway_registry_namespace.this.endpoint
  }
}
