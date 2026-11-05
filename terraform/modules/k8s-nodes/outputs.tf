output "control_plane_name" {
  value = google_compute_instance.control_plane.name
}

output "control_plane_internal_ip" {
  value = google_compute_instance.control_plane.network_interface[0].network_ip
}

output "worker_names" {
  value = google_compute_instance.workers[*].name
}

output "worker_instance_group" {
  value = google_compute_instance_group.workers.self_link
}

output "node_service_account" {
  value = google_service_account.nodes.email
}
