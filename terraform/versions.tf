terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  # Local state on purpose (docs/decisions.md). terraform.tfstate is gitignored – it contains the DB password.

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.14.2"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  # Resource providers were registered once by hand (see docs/test-log-azure.md, Step 4).
  resource_provider_registrations = "none"

  features {
    key_vault {
      # Throw-away test environment: purge the soft-deleted vault on destroy.
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
