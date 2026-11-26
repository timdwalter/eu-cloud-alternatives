variable "project_id" {
  description = "Scaleway project to deploy into (scw account project list)."
  type        = string
}

variable "prefix" {
  description = "Short lowercase name prefix for all resources (letters and digits, 3–10 chars)."
  type        = string
  default     = "textlib"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.prefix))
    error_message = "prefix must be 3–10 lowercase letters/digits and start with a letter."
  }
}

variable "region" {
  description = "Scaleway region."
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone for zonal resources (nodes, load balancer, database node)."
  type        = string
  default     = "fr-par-1"
}

variable "kubernetes_version" {
  description = "Kapsule Kubernetes version (scw k8s version list)."
  type        = string
  default     = "1.36.6"
}

variable "node_size" {
  description = "Instance type of the single node pool."
  type        = string
  default     = "PLAY2-NANO"
}

variable "node_count" {
  description = "Number of nodes."
  type        = number
  default     = 2
}
