variable "project_id" {
  type = string
}

variable "name_prefix" {
  description = "Prefix for VM names, e.g. k8s-dev -> k8s-dev-cp-1, k8s-dev-worker-1."
  type        = string
}

variable "zone" {
  type = string
}

variable "subnetwork" {
  description = "Self link of the subnet the nodes live in."
  type        = string
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "control_plane_machine_type" {
  description = "kubeadm needs at least 2 vCPU / 2 GB on the control plane."
  type        = string
  default     = "e2-medium"
}

variable "worker_machine_type" {
  description = "Where your apps run. e2-medium = 2 shared vCPU / 4 GB. Use e2-standard-2 (8 GB) if pods stay Pending."
  type        = string
  default     = "e2-medium"
}

variable "image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "k8s_minor" {
  description = "Kubernetes minor version for the apt repo, e.g. v1.35. Check https://kubernetes.io/releases/ for supported versions."
  type        = string
  default     = "v1.35"

  validation {
    condition     = can(regex("^v1\\.[0-9]+$", var.k8s_minor))
    error_message = "k8s_minor must look like v1.35."
  }
}
