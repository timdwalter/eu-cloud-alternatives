# OVHcloud Public Cloud: one private network (vRack) with one subnet. The Kubernetes nodes and the
# PostgreSQL service attach to it; the database is reachable only from that network.
# Uses the current ovh_cloud_* resources (API v2); the ovh_cloud_project_* network resources are deprecated.

locals {
  name        = var.prefix
  subnet_cidr = "10.20.0.0/24"
}

resource "ovh_cloud_network_private_vrack" "this" {
  service_name = var.project_id
  name         = "${local.name}-private"
  region       = var.region
  vlan_id      = 20
}

resource "ovh_cloud_network_private_vrack_subnet" "this" {
  service_name = var.project_id
  network_id   = ovh_cloud_network_private_vrack.this.id
  region       = var.region
  name         = "${local.name}-subnet"
  cidr         = local.subnet_cidr
  dhcp_enabled = true
  gateway_ip   = cidrhost(local.subnet_cidr, 1)

  allocation_pools = [{
    start = cidrhost(local.subnet_cidr, 10)
    end   = cidrhost(local.subnet_cidr, 200)
  }]
}

# Smallest gateway: router for the subnet, so the cluster's load balancer can get a Floating IP.
resource "ovh_cloud_gateway" "this" {
  service_name = var.project_id
  name         = "${local.name}-gw"
  region       = var.region
  subnet_ids   = [ovh_cloud_network_private_vrack_subnet.this.id]

  external_gateway = {
    enabled = true
    model   = "s"
  }
}
