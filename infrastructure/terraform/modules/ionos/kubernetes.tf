resource "ionoscloud_k8s_cluster" "this" {
  name        = "${local.name}-k8s"
  k8s_version = var.kubernetes_version

  maintenance_window {
    day_of_the_week = "Sunday"
    time            = "03:00:00Z"
  }
}

# Public node pool: only public pools support Service type=LoadBalancer (IONOS attaches the public IP
# to one node). The private LAN gives the pods a route to the database.
resource "ionoscloud_k8s_node_pool" "default" {
  name              = "${local.name}-pool"
  k8s_cluster_id    = ionoscloud_k8s_cluster.this.id
  k8s_version       = var.kubernetes_version
  datacenter_id     = ionoscloud_datacenter.this.id
  node_count        = var.node_count
  server_type       = "VCPU"
  cores_count       = var.node_cores
  ram_size          = var.node_ram_mb
  availability_zone = "AUTO"
  storage_type      = "SSD"
  storage_size      = 20

  lans {
    id   = tonumber(ionoscloud_lan.private.id)
    dhcp = true
  }

  maintenance_window {
    day_of_the_week = "Sunday"
    time            = "04:00:00Z"
  }
}
