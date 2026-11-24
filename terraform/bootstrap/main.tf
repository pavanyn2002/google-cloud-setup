# Bootstrap: run ONCE per project, with local state.
# Creates the GCS bucket that every other Terraform config stores its state in,
# and turns on the Google Cloud APIs the platform needs.

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  apis = [
    "compute.googleapis.com",              # VMs, VPC, load balancers
    "iap.googleapis.com",                  # SSH to private VMs without public IPs
    "artifactregistry.googleapis.com",     # private Docker registry
    "iam.googleapis.com",                  # service accounts
    "cloudresourcemanager.googleapis.com", # project-level IAM
    "secretmanager.googleapis.com",        # used in Stage 12
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "container.googleapis.com",      # GKE (envs/prod)
    "sts.googleapis.com",            # Workload Identity Federation for GitHub Actions
    "billingbudgets.googleapis.com", # budget alerts
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false # destroying Terraform must never switch off APIs other things use
}

resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false # protects your state from an accidental destroy

  versioning {
    enabled = true # every state change is kept, so a bad apply can be rolled back
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 20
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    purpose    = "terraform-state"
    managed-by = "terraform"
  }
}
