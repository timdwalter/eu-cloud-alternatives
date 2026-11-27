# Provider module interface – identical outputs for every provider module.

output "cluster_name" {
  value = ionoscloud_k8s_cluster.this.name
}

output "kube_credentials_command" {
  # ionosctl writes the kubeconfig to stdout; the provider script stores it in ~/.kube.
  value = "ionosctl k8s kubeconfig get --cluster-id ${ionoscloud_k8s_cluster.this.id}"
}

output "registry_login_server" {
  value = ionoscloud_container_registry.this.hostname
}

output "db_host" {
  # DNS name, not the IP: the Let's Encrypt server certificate is issued for the name.
  value = ionoscloud_pg_cluster_v2.this.dns_name
}

output "db_user" {
  value = "textlib_admin"
}

output "secret_store_name" {
  # No secret store on IONOS: the DB password is only in the local Terraform state.
  value = "terraform-state"
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "registry_pull_user" {
  value = ionoscloud_container_registry_token.pull.credentials[0].username
}

output "registry_pull_password" {
  value     = ionoscloud_container_registry_token.pull.credentials[0].password
  sensitive = true
}

output "registry_ci_password" {
  value     = ionoscloud_container_registry_token.ci.credentials[0].password
  sensitive = true
}

output "ci_variables" {
  value = {
    REGISTRY          = ionoscloud_container_registry.this.hostname
    REGISTRY_USERNAME = ionoscloud_container_registry_token.ci.credentials[0].username
  }
}
