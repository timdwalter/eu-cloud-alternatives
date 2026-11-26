variable "subscription_id" {
  description = "Azure subscription to deploy into."
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

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (az aks get-versions --location <region>)."
  type        = string
  default     = "1.36.5"
}

variable "node_size" {
  description = "VM size of the single node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Number of nodes."
  type        = number
  default     = 2
}

variable "github_repository" {
  description = "GitHub repository allowed to push images, as owner/name."
  type        = string
}

variable "github_oidc_subject" {
  description = <<-EOT
    Exact "sub" claim of the GitHub OIDC token for pushes to main. Newer repositories use the
    immutable form repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main (shown in the error
    message of a failed azure/login). Null = classic form repo:<owner>/<repo>:ref:refs/heads/main.
  EOT
  type        = string
  default     = null
}
