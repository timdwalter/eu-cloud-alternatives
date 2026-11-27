variable "project_id" {
  description = "Public Cloud project ID (ovhcloud cloud project list)."
  type        = string
}

variable "okms_id" {
  description = "Secret Manager (OKMS) ID, created once in the console (ovhcloud okms list)."
  type        = string
}

variable "registry_user_email" {
  description = "E-mail address required by the registry for its two users."
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
  description = "Compute/Kubernetes region (DE1 = Frankfurt, Free MKS plan available)."
  type        = string
  default     = "DE1"
}

variable "db_region" {
  description = "Region name for Public Cloud Databases."
  type        = string
  default     = "DE"
}

variable "registry_region" {
  description = "Region name for Managed Private Registry."
  type        = string
  default     = "DE"
}

variable "kubernetes_version" {
  description = "MKS version (null = default offered by OVHcloud)."
  type        = string
  default     = null
}

variable "node_flavor" {
  description = "Worker node flavor (d2-4 = 2 vCPU, 4 GB)."
  type        = string
  default     = "d2-4"
}

variable "node_count" {
  description = "Number of nodes."
  type        = number
  default     = 2
}
