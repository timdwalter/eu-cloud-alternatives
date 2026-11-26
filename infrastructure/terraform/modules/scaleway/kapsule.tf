resource "scaleway_k8s_cluster" "this" {
  name               = "${local.name}-k8s"
  type               = "kapsule" # mutualized control plane, free
  version            = var.kubernetes_version
  cni                = "cilium"
  region             = var.region
  private_network_id = scaleway_vpc_private_network.this.id
  tags               = var.tags

  # Also delete load balancers and volumes created by the cluster on destroy
  delete_additional_resources = true
}

resource "scaleway_k8s_pool" "default" {
  cluster_id             = scaleway_k8s_cluster.this.id
  name                   = "default"
  node_type              = var.node_size
  size                   = var.node_count
  zone                   = var.zone
  root_volume_size_in_gb = 20
  wait_for_pool_ready    = true
  tags                   = var.tags
}
