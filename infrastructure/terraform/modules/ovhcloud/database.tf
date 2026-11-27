# Public Cloud Databases for PostgreSQL, smallest offer (Essential, 1 node), attached to the private
# network only – no public endpoint. Access additionally limited to the subnet.
resource "ovh_cloud_project_database" "this" {
  service_name = var.project_id
  description  = "${local.name}-pg"
  engine       = "postgresql"
  version      = "17"
  plan         = "essential"
  flavor       = "db1-4"

  nodes {
    region     = var.db_region
    network_id = ovh_cloud_network_private_vrack.this.id
    subnet_id  = ovh_cloud_network_private_vrack_subnet.this.id
  }

  ip_restrictions {
    ip          = local.subnet_cidr
    description = "private subnet"
  }

  depends_on = [ovh_cloud_gateway.this]
}

# Both databases are created by Terraform here (unlike IONOS PostgreSQL v2).
resource "ovh_cloud_project_database_database" "app" {
  service_name = var.project_id
  engine       = "postgresql"
  cluster_id   = ovh_cloud_project_database.this.id
  name         = "app"
}

resource "ovh_cloud_project_database_database" "keycloak" {
  service_name = var.project_id
  engine       = "postgresql"
  cluster_id   = ovh_cloud_project_database.this.id
  name         = "keycloak"
}

# Application user; OVHcloud generates the password (stored in Secret Manager, see registry-secrets.tf).
resource "ovh_cloud_project_database_postgresql_user" "app" {
  service_name = var.project_id
  cluster_id   = ovh_cloud_project_database.this.id
  name         = "textlib_admin"
}

locals {
  db_host = one([for e in ovh_cloud_project_database.this.endpoints : e.domain if e.component == "postgresql"])
}
