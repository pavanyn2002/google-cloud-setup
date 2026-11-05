output "ingress_ip" {
  description = "Public IP for all apps. Point DNS here."
  value       = module.ingress_lb.ip_address
}

output "control_plane" {
  value = module.nodes.control_plane_name
}

output "control_plane_internal_ip" {
  value = module.nodes.control_plane_internal_ip
}

output "workers" {
  value = module.nodes.worker_names
}

output "registry" {
  description = "Image prefix: docker push <registry>/<app>:<tag>"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}"
}

output "ssh_control_plane" {
  value = "gcloud compute ssh ${module.nodes.control_plane_name} --zone=${var.zone} --tunnel-through-iap"
}
