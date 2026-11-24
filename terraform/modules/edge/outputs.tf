output "gateway_ip" {
  value = google_compute_global_address.gateway.address
}

output "gateway_ip_name" {
  description = "Use as the Gateway's NamedAddress."
  value       = google_compute_global_address.gateway.name
}

output "security_policy_name" {
  description = "Reference from each app's GCPBackendPolicy."
  value       = google_compute_security_policy.cloudflare_only.name
}
