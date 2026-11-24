# Keyless identities. No JSON keys anywhere for CI or for apps in the cluster.

# --- GitHub Actions -> Google Cloud (Workload Identity Federation) ---------------------

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Lets our GitHub repositories push images without stored keys"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only our organisation, and only the branches that build images.
  attribute_condition = "assertion.repository_owner == '${var.github_org}' && assertion.ref in ${jsonencode(var.github_build_refs)}"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "ci" {
  account_id   = "github-ci"
  display_name = "GitHub Actions: build and push images"
}

resource "google_artifact_registry_repository_iam_member" "ci_write" {
  location   = google_artifact_registry_repository.apps.location
  repository = google_artifact_registry_repository.apps.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}

# Each listed repository may act as the CI service account.
resource "google_service_account_iam_member" "ci_wif" {
  for_each = toset(var.github_repos)

  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${each.value}"
}

# --- External Secrets Operator (in the cluster) -> Secret Manager -----------------------

resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets"
  display_name = "External Secrets Operator: read production secrets"
}

resource "google_project_iam_member" "external_secrets_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# The Kubernetes service account external-secrets/external-secrets acts as this Google account.
resource "google_service_account_iam_member" "external_secrets_wi" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.gke.workload_pool}[external-secrets/external-secrets]"

  depends_on = [module.gke] # the workload identity pool exists once the cluster does
}
