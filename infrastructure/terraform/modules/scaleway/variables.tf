# Provider module interface – the outputs are identical to modules/azure; inputs differ only where the
# provider needs it (region/zone instead of location, no GitHub OIDC: Scaleway has no federation).

variable "prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "node_size" {
  type = string
}

variable "node_count" {
  type = number
}

variable "tags" {
  type = list(string)
}
