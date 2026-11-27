# Provider module interface – same inputs as the other provider modules where the concept exists.

variable "prefix" {
  type = string
}

variable "project_id" {
  description = "Public Cloud project ID (service_name)."
  type        = string
}

variable "region" {
  description = "Compute/Kubernetes region, e.g. DE1."
  type        = string
}

variable "db_region" {
  description = "Region name used by Public Cloud Databases, e.g. DE."
  type        = string
}

variable "registry_region" {
  description = "Region name used by Managed Private Registry, e.g. DE."
  type        = string
}

variable "okms_id" {
  description = "ID of the Secret Manager (OKMS) created once in the console and covered by the IAM policy."
  type        = string
}

variable "kubernetes_version" {
  description = "MKS version; null = default version offered."
  type        = string
  default     = null
}

variable "node_flavor" {
  type = string
}

variable "node_count" {
  type = number
}

variable "registry_user_email" {
  description = "E-mail address the registry requires for its users (stays in terraform.tfvars, never in Git)."
  type        = string
}
