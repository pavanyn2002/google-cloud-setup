# Public entry point for all apps: a static IP + regional external passthrough
# Network Load Balancer that forwards TCP 80/443 to the workers. On the workers,
# Traefik listens on ports 80/443 (hostPort) and routes by hostname to each app.
#
# Passthrough means the LB does not terminate TLS - cert-manager + Traefik
# do HTTPS inside the cluster (Stage 11).

resource "google_compute_address" "ingress" {
  name         = "${var.name}-ip"
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_region_health_check" "ingress" {
  name   = "${var.name}-hc"
  region = var.region

  tcp_health_check {
    port = 80 # healthy once Traefik is running on the worker
  }
}

resource "google_compute_region_backend_service" "ingress" {
  name                  = "${var.name}-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.ingress.id]

  backend {
    group          = var.worker_instance_group
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "ingress" {
  name                  = "${var.name}-fr"
  region                = var.region
  ip_address            = google_compute_address.ingress.address
  ip_protocol           = "TCP"
  ports                 = ["80", "443"]
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.ingress.id
}
