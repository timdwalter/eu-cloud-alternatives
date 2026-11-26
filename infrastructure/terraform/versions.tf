terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  # Local state on purpose (docs/decisions.md). terraform.tfstate is gitignored – it contains the DB password.

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "= 2.92.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
  }
}

# Credentials come from the Scaleway CLI profile set in SCW_PROFILE (e.g. "textlib-terraform"), a
# project-scoped IAM application key – never from this repository.
provider "scaleway" {
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}
