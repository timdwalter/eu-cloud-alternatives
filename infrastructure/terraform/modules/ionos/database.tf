resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "-_"
}

# DBaaS PostgreSQL v2 (the v1 API is being retired – the CLI already gets "410 Gone" for it).
# Smallest size IONOS allows: 1 core, 4 GB RAM. Private LAN connection only, no public endpoint.
# v2 creates exactly one initial database ("app"); the "keycloak" database is created by
# infrastructure/scripts/providers/ionos.sh before the chart is installed.
resource "ionoscloud_pg_cluster_v2" "this" {
  name             = "${local.name}-pg"
  description      = "textlib test (managed by Terraform)"
  version          = "17"
  location         = var.location
  replication_mode = "ASYNCHRONOUS"

  backup = {
    location       = "eu-central-3"
    retention_days = 7
  }

  instances = {
    count        = 1
    cores        = 1
    ram          = 4
    storage_size = 10
  }

  connections = {
    datacenter_id            = ionoscloud_datacenter.this.id
    lan_id                   = ionoscloud_lan.private.id
    primary_instance_address = local.db_cidr
  }

  maintenance_window = {
    day_of_the_week = "Sunday"
    time            = "02:00:00"
  }

  credentials = {
    username         = "textlib_admin"
    password         = random_password.db.result
    password_version = "1"
    database         = "app"
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }
}
