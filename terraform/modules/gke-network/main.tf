# Private VPC for the GKE production cluster.
# - nodes get NO public IPs
# - ALL outbound traffic leaves through Cloud NAT with ONE reserved static IP.
#   That IP is what MongoDB Atlas and Supabase allow-list, so it must never change.
# - pods and services get their own secondary ranges (VPC-native GKE)

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
  private_ip_google_access = true # reach Google APIs (registry, secrets) without public IPs

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_router" "router" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# The fixed outgoing address. Add it to the MongoDB Atlas and Supabase allow-lists.
resource "google_compute_address" "nat" {
  name         = "${var.name}-nat-ip"
  region       = var.region
  address_type = "EXTERNAL"
  description  = "Static egress IP for production; allow-listed at MongoDB Atlas and Supabase"
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name}-nat"
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "MANUAL_ONLY" # AUTO_ONLY could change the IP and break the allow-lists
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# SSH to nodes only through Google's Identity-Aware Proxy range (rarely needed on GKE).
# GKE creates the load-balancer health-check firewall rules itself.
resource "google_compute_firewall" "iap_ssh" {
  name      = "${var.name}-allow-iap-ssh"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["gke-node"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
