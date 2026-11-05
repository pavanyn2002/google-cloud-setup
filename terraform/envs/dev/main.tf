# dev environment: network + Kubernetes VMs + load balancer + image registry.

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }

  # The bucket name is passed at init time (backends cannot use variables):
  #   terraform init -backend-config="bucket=YOUR_PROJECT_ID-tfstate"
  backend "gcs" {
    prefix = "envs/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = {
    env        = "dev"
    managed-by = "terraform"
  }
}

locals {
  name = "k8s-dev"
}

module "network" {
  source = "../../modules/network"

  name        = local.name
  region      = var.region
  subnet_cidr = "10.10.0.0/24"
  pod_cidr    = "192.168.0.0/16"
}

module "nodes" {
  source = "../../modules/k8s-nodes"

  project_id                 = var.project_id
  name_prefix                = local.name
  zone                       = var.zone
  subnetwork                 = module.network.subnet_self_link
  worker_count               = var.worker_count
  control_plane_machine_type = "e2-medium"
  worker_machine_type        = var.worker_machine_type
  k8s_minor                  = var.k8s_minor

  # Create NAT + firewall rules before the VMs, so their startup script can reach the internet.
  depends_on = [module.network]
}

module "ingress_lb" {
  source = "../../modules/ingress-lb"

  name                  = local.name
  region                = var.region
  worker_instance_group = module.nodes.worker_instance_group
}

# Private Docker registry for your 5 apps' images.
resource "google_artifact_registry_repository" "apps" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  description   = "Container images for the company apps"
}
