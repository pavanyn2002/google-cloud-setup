# GKE Standard production cluster.
# Google runs the control plane (upgrades, repairs, etcd backups). We run only the apps.
# - zonal control plane, nodes spread over two zones (one node per zone by default)
# - private nodes; outbound through the network module's Cloud NAT static IP
# - Workload Identity: apps get Google permissions without any key files
# - Dataplane V2: Kubernetes NetworkPolicies are enforced
# - Gateway API: Google load balancer managed from Kubernetes manifests

# Dedicated, minimal service account for the nodes (never the default compute SA).
resource "google_service_account" "nodes" {
  account_id   = "${var.name}-nodes"
  display_name = "GKE nodes (${var.name})"
}

resource "google_project_iam_member" "nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount" # logs, metrics, node basics only
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  name           = var.name
  location       = var.zone        # zonal control plane
  node_locations = var.extra_zones # plus these zones for the nodes

  network         = var.network_self_link
  subnetwork      = var.subnet_self_link
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # No default node pool: the node pool below is managed separately, so it can change
  # without recreating the cluster (initial_node_count / node_config intentionally omitted).

  deletion_protection = var.deletion_protection

  release_channel {
    channel = var.release_channel
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start
      end_time   = var.maintenance_end
      recurrence = var.maintenance_recurrence
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  datapath_provider = "ADVANCED_DATAPATH" # Dataplane V2: enforces NetworkPolicies

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  # kubectl through the DNS endpoint, authorised by Google IAM (no open IP endpoint).
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  # Optional extra: allow the IP endpoint only from these admin networks.
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  enable_shielded_nodes = true
  resource_labels       = var.labels
}

resource "google_container_node_pool" "main" {
  name     = "main"
  cluster  = google_container_cluster.this.id
  location = var.zone

  initial_node_count = 1 # per zone

  autoscaling {
    min_node_count  = var.min_nodes_per_zone
    max_node_count  = var.max_nodes_per_zone
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0 # upgrades never take a node away before its replacement is ready
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-balanced"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"] # real access limited by IAM

    workload_metadata_config {
      mode = "GKE_METADATA" # pods use Workload Identity, never the node's identity
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    tags   = ["gke-node"]
    labels = var.labels
  }

  lifecycle {
    ignore_changes = [initial_node_count] # the autoscaler owns the node count
  }
}
