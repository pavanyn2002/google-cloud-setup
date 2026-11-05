# The Kubernetes VMs: 1 control plane + N workers, all private (no public IPs).

locals {
  startup_script = templatefile("${path.module}/node-prep.sh.tftpl", {
    k8s_minor = var.k8s_minor
  })

  # Settings shared by every node
  common_tags = ["k8s"]
}

# Dedicated, minimal service account for the nodes (never use the default compute SA).
resource "google_service_account" "nodes" {
  account_id   = "${var.name_prefix}-nodes"
  display_name = "Kubernetes nodes (${var.name_prefix})"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_compute_instance" "control_plane" {
  name         = "${var.name_prefix}-cp-1"
  zone         = var.zone
  machine_type = var.control_plane_machine_type
  tags         = concat(local.common_tags, ["control-plane"])

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork
    # no access_config block = no public IP
  }

  service_account {
    email  = google_service_account.nodes.email
    scopes = ["cloud-platform"] # real access is limited by the IAM roles above
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = local.startup_script
  }

  labels = {
    role = "control-plane"
  }

  lifecycle {
    # A newer Ubuntu image in the family must NOT rebuild your nodes. Upgrades are deliberate.
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [google_project_iam_member.nodes]
}

resource "google_compute_instance" "workers" {
  count = var.worker_count

  name         = "${var.name_prefix}-worker-${count.index + 1}"
  zone         = var.zone
  machine_type = var.worker_machine_type
  tags         = concat(local.common_tags, ["worker"])

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork
  }

  service_account {
    email  = google_service_account.nodes.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = local.startup_script
  }

  labels = {
    role = "worker"
  }

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [google_project_iam_member.nodes]
}

# Groups the workers so the load balancer can send traffic to them.
resource "google_compute_instance_group" "workers" {
  name      = "${var.name_prefix}-workers"
  zone      = var.zone
  instances = google_compute_instance.workers[*].self_link

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "https"
    port = 443
  }
}
