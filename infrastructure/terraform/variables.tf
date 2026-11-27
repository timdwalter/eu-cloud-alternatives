variable "prefix" {
  description = "Short lowercase name prefix for all resources (letters and digits, 3–10 chars)."
  type        = string
  default     = "textlib"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.prefix))
    error_message = "prefix must be 3–10 lowercase letters/digits and start with a letter."
  }
}

variable "location" {
  description = "IONOS location (ionosctl location list). The container registry exists only in de/fra."
  type        = string
  default     = "de/fra"
}

variable "kubernetes_version" {
  description = "Kubernetes version (ionosctl k8s version list)."
  type        = string
  default     = "1.36.6"
}

variable "node_count" {
  description = "Number of nodes."
  type        = number
  default     = 2
}

variable "node_cores" {
  description = "vCPUs per node (IONOS has no VM sizes)."
  type        = number
  default     = 2
}

variable "node_ram_mb" {
  description = "RAM per node in MB."
  type        = number
  default     = 4096
}
