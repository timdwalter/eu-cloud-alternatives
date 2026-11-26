# Provider module interface – identical inputs for every provider module.

variable "prefix" {
  type = string
}

variable "location" {
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

variable "github_repository" {
  description = "owner/name of the repository whose main branch may push images."
  type        = string
}

variable "github_oidc_subject" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}
