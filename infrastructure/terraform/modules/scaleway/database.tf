resource "random_password" "db" {
  length = 32
  # Scaleway requires upper, lower, digit and special characters
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_"
}

resource "scaleway_rdb_instance" "this" {
  name              = "${local.name}-pg"
  node_type         = "DB-PLAY2-PICO"
  engine            = "PostgreSQL-17"
  is_ha_cluster     = false
  region            = var.region
  user_name         = "textlib_admin"
  password          = random_password.db.result
  volume_type       = "sbs_5k"
  volume_size_in_gb = 10
  tags              = var.tags

  # Private Network endpoint only. No load_balancer block = no public endpoint.
  private_network {
    pn_id       = scaleway_vpc_private_network.this.id
    enable_ipam = true
  }
}

resource "scaleway_rdb_database" "app" {
  instance_id = scaleway_rdb_instance.this.id
  name        = "app"
}

resource "scaleway_rdb_database" "keycloak" {
  instance_id = scaleway_rdb_instance.this.id
  name        = "keycloak"
}

# Unlike Azure, the instance's admin user has no rights on databases created separately.
resource "scaleway_rdb_privilege" "app" {
  instance_id   = scaleway_rdb_instance.this.id
  user_name     = scaleway_rdb_instance.this.user_name
  database_name = scaleway_rdb_database.app.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "keycloak" {
  instance_id   = scaleway_rdb_instance.this.id
  user_name     = scaleway_rdb_instance.this.user_name
  database_name = scaleway_rdb_database.keycloak.name
  permission    = "all"
}
