# MKS Free plan: free control plane, single zone (same class as AKS Free tier / Kapsule mutualized).
resource "ovh_cloud_project_kube" "this" {
  service_name       = var.project_id
  name               = "${local.name}-k8s"
  region             = var.region
  version            = var.kubernetes_version
  plan               = "free"
  private_network_id = ovh_cloud_network_private_vrack.this.id
  nodes_subnet_id    = ovh_cloud_network_private_vrack_subnet.this.id

  depends_on = [ovh_cloud_gateway.this]
}

resource "ovh_cloud_project_kube_nodepool" "default" {
  service_name  = var.project_id
  kube_id       = ovh_cloud_project_kube.this.id
  name          = "${local.name}-pool"
  flavor_name   = var.node_flavor
  desired_nodes = var.node_count
  min_nodes     = var.node_count
  max_nodes     = var.node_count
  autoscale     = false
}
