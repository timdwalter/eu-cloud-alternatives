resource "scaleway_registry_namespace" "this" {
  name      = "${local.name}-${local.suffix}"
  region    = var.region
  is_public = false # cluster pulls with a pull secret (no keyless pull on Kapsule)
}

resource "scaleway_secret" "db_password" {
  name   = "db-password"
  region = var.region
  tags   = var.tags
}

resource "scaleway_secret_version" "db_password" {
  secret_id = scaleway_secret.db_password.id
  region    = var.region
  data      = random_password.db.result
}
