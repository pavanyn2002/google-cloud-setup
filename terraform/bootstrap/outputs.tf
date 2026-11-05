output "state_bucket" {
  description = "Pass this to `terraform init -backend-config=\"bucket=...\"` in envs/dev."
  value       = google_storage_bucket.tfstate.name
}
