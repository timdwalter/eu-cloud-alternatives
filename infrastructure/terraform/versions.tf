terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  # Local state on purpose (docs/decisions.md). terraform.tfstate is gitignored – it contains the
  # kubeconfig and the registry user passwords.

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "= 2.24.0"
    }
  }
}

# Credentials: OVH_CLIENT_ID / OVH_CLIENT_SECRET of the service account textlib-terraform, whose IAM
# policy covers only the Public Cloud project and the Secret Manager (never in Git).
provider "ovh" {
  endpoint = "ovh-eu"
}
