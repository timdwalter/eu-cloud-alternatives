terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  # Local state on purpose (docs/decisions.md). terraform.tfstate is gitignored – it contains the DB password
  # and the registry token passwords.

  required_providers {
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = "= 6.7.41"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
  }
}

# Credentials: IONOS_TOKEN of the least-privilege user textlib-terraform (never in Git).
provider "ionoscloud" {}
