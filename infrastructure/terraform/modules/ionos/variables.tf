# Provider module interface – same inputs as the other provider modules where the concept exists.

variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "node_count" {
  type = number
}

# IONOS has no VM sizes: cores and RAM are set per node pool.
variable "node_cores" {
  type = number
}

variable "node_ram_mb" {
  type = number
}
