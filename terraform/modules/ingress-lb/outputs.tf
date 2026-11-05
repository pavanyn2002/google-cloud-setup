output "ip_address" {
  description = "Point your app DNS records (e.g. *.dev.yourdomain.com) at this IP."
  value       = google_compute_address.ingress.address
}
