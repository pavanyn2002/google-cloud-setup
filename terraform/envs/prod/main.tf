# Production environment: GKE cluster for Direct, Connect and Partner.
# Dev and test run on our Hostinger server (Coolify), so this project holds production only.

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.14"
    }
  }

  # terraform init -backend-config="bucket=YOUR_PROJECT_ID-tfstate"
  backend "gcs" {
    prefix = "envs/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = {
    env        = "prod"
    managed-by = "terraform"
  }
}

locals {
  name = "tatva-prod"
}

module "network" {
  source = "../../modules/gke-network"

  name          = local.name
  region        = var.region
  subnet_cidr   = "10.10.0.0/24"
  pods_cidr     = "10.20.0.0/16"
  services_cidr = "10.30.0.0/20"
}

module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  name                = local.name
  zone                = var.zone
  extra_zones         = var.extra_zones
  network_self_link   = module.network.network_self_link
  subnet_self_link    = module.network.subnet_self_link
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  machine_type        = var.machine_type
  min_nodes_per_zone  = var.min_nodes_per_zone
  max_nodes_per_zone  = var.max_nodes_per_zone
  authorized_networks = var.authorized_networks
  labels              = { env = "prod" }

  # Cloud NAT must exist before nodes start pulling images.
  depends_on = [module.network]
}

module "edge" {
  source = "../../modules/edge"

  name = local.name
}
