# Provider module interface – identical outputs for every provider module.

output "cluster_name" {
  value = ovh_cloud_project_kube.this.name
}

output "kube_credentials_command" {
  # The kubeconfig comes from the Terraform state; providers/ovhcloud.sh merges it into ~/.kube/config.
  value = "terraform output -raw kubeconfig"
}

output "registry_login_server" {
  value = trimprefix(ovh_cloud_project_containerregistry.this.url, "https://")
}

output "db_host" {
  value = local.db_host
}

output "db_user" {
  value = ovh_cloud_project_database_postgresql_user.app.name
}

output "secret_store_name" {
  # "<okms id>/<secret path>" – read by get_secret in providers/ovhcloud.sh
  value = "${var.okms_id}/${ovh_okms_secret.db_password.path}"
}

output "kubeconfig" {
  value     = ovh_cloud_project_kube.this.kubeconfig
  sensitive = true
}

output "registry_pull_user" {
  value = ovh_cloud_project_containerregistry_user.pull.user
}

output "registry_pull_password" {
  value     = ovh_cloud_project_containerregistry_user.pull.password
  sensitive = true
}

output "registry_ci_password" {
  value     = ovh_cloud_project_containerregistry_user.ci.password
  sensitive = true
}

output "ci_variables" {
  value = {
    REGISTRY          = trimprefix(ovh_cloud_project_containerregistry.this.url, "https://")
    REGISTRY_USERNAME = ovh_cloud_project_containerregistry_user.ci.user
  }
}
