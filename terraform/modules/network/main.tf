# Private VPC for the Kubernetes nodes:
# - nodes get NO public IPs
# - outbound internet (apt, image pulls) goes through Cloud NAT
# - you reach nodes over IAP (SSH and the Kubernetes API), never from the open internet
# - only ports 80/443 on workers are reachable publicly, via the load balancer

resource "google_compute_network" "vpc" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "nodes" {
  name                     = "${var.name}-nodes"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true # reach Google APIs without public IPs
}

resource "google_compute_router" "router" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name}-nat"
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Node <-> node traffic: kubelet, etcd, Calico VXLAN (UDP 4789), NodePorts...
resource "google_compute_firewall" "internal" {
  name      = "${var.name}-allow-internal"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.subnet_cidr, var.pod_cidr]
  target_tags   = ["k8s"]

  allow {
    protocol = "all"
  }
}

# Google's IAP range: SSH and kubectl (6443) via `gcloud compute start-iap-tunnel`.
resource "google_compute_firewall" "iap" {
  name      = "${var.name}-allow-iap"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["k8s"]

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }
}

# Public web traffic. The load balancer is passthrough, so packets arrive with the
# real client IP - which is why the source is 0.0.0.0/0. This also covers LB health checks.
resource "google_compute_firewall" "web" {
  name      = "${var.name}-allow-web"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["worker"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}
