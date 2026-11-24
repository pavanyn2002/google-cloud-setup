output "nat_ip" {
  description = "Static OUTGOING IP: allow-list it in MongoDB Atlas and Supabase."
  value       = module.network.nat_ip
}

output "gateway_ip" {
  description = "Static INCOMING IP: point the API hostnames here in Cloudflare (proxied)."
  value       = module.edge.gateway_ip
}

output "gateway_ip_name" {
  description = "NamedAddress for the Gateway in platform/gke/gateway.yaml."
  value       = module.edge.gateway_ip_name
}

output "cloud_armor_policy" {
  description = "securityPolicy name for each app's GCPBackendPolicy."
  value       = module.edge.security_policy_name
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "get_credentials" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --location=${module.gke.location} --dns-endpoint"
}

output "registry" {
  description = "Image prefix: docker push <registry>/<app>:<git-sha>"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}"
}

output "github_wif_provider" {
  description = "workload_identity_provider for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_ci_service_account" {
  value = google_service_account.ci.email
}

output "external_secrets_service_account" {
  description = "Annotate the external-secrets/external-secrets Kubernetes service account with this."
  value       = google_service_account.external_secrets.email
}

output "coolify_puller_service_account" {
  description = "Create its read-only key by hand for the Coolify servers (see docs)."
  value       = google_service_account.coolify_puller.email
}
