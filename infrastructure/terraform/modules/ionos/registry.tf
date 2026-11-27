resource "ionoscloud_container_registry" "this" {
  name     = "${local.name}-${random_string.suffix.result}"
  location = var.location # the registry is only offered in de/fra

  garbage_collection_schedule {
    days = ["Sunday"]
    time = "05:00:00+00:00"
  }
}

# No keyless pull and no OIDC for CI on IONOS: two registry tokens with minimal scopes, short-lived.
# Their passwords end up in the local Terraform state only (gitignored).
resource "ionoscloud_container_registry_token" "pull" {
  name        = "cluster-pull"
  registry_id = ionoscloud_container_registry.this.id
  # The provider expects "YYYY-MM-DD hh:mm:ssZ" (space, not ISO 8601 "T")
  expiry_date = formatdate("YYYY-MM-DD hh:mm:ssZ", timeadd(plantimestamp(), "168h"))

  scopes {
    name    = "*"
    type    = "repository"
    actions = ["pull"]
  }

  lifecycle {
    ignore_changes = [expiry_date]
  }
}

resource "ionoscloud_container_registry_token" "ci" {
  name        = "ci-push"
  registry_id = ionoscloud_container_registry.this.id
  # The provider expects "YYYY-MM-DD hh:mm:ssZ" (space, not ISO 8601 "T")
  expiry_date = formatdate("YYYY-MM-DD hh:mm:ssZ", timeadd(plantimestamp(), "168h"))

  # Push requires pull on IONOS; no delete.
  scopes {
    name    = "*"
    type    = "repository"
    actions = ["pull", "push"]
  }

  lifecycle {
    ignore_changes = [expiry_date]
  }
}
