# One private Docker registry for every app image (dev, test and prod use the same images).
#
# If envs/dev already created the "apps" repository, move it here instead of creating a
# second one (see docs/02-gke-production.md, "Moving the registry").
resource "google_artifact_registry_repository" "apps" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  description   = "Container images for the company apps"

  cleanup_policy_dry_run = false

  # Keep the 20 newest images of every app (rollback targets), delete the rest after 30 days.
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 20
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }
}

# GKE nodes may pull images, nothing else.
resource "google_artifact_registry_repository_iam_member" "nodes_read" {
  location   = google_artifact_registry_repository.apps.location
  repository = google_artifact_registry_repository.apps.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${module.gke.node_service_account}"
}

# Read-only identity for the Coolify servers (Hostinger). Its JSON key is created by hand,
# stored root-only on the servers and rotated every 90 days; it is never in Terraform state.
resource "google_service_account" "coolify_puller" {
  account_id   = "coolify-image-puller"
  display_name = "Coolify servers: pull images (read-only)"
}

resource "google_artifact_registry_repository_iam_member" "coolify_read" {
  location   = google_artifact_registry_repository.apps.location
  repository = google_artifact_registry_repository.apps.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.coolify_puller.email}"
}
