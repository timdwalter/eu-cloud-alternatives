# IONOS Cloud: one virtual data center with one private LAN. The Kubernetes node pool and the
# PostgreSQL cluster both attach to that LAN; the database has no public endpoint.

locals {
  name = var.prefix
  # Fixed private range so the DB can get a fixed address (.2–.10 are reserved for managed services).
  lan_cidr = "10.20.0.0/24"
  db_cidr  = "${cidrhost(local.lan_cidr, 5)}/24"
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "ionoscloud_datacenter" "this" {
  name        = local.name
  location    = var.location
  description = "textlib test (managed by Terraform)"
}

resource "ionoscloud_lan" "private" {
  datacenter_id   = ionoscloud_datacenter.this.id
  name            = "${local.name}-private"
  public          = false
  ipv4_cidr_block = local.lan_cidr
}
