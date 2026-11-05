variable "name" {
  description = "Name prefix for the VPC and everything in it."
  type        = string
}

variable "region" {
  type = string
}

variable "subnet_cidr" {
  description = "IP range for the node VMs."
  type        = string
  default     = "10.10.0.0/24"
}

variable "pod_cidr" {
  description = "Kubernetes pod IP range. Must match kubeadm --pod-network-cidr and Calico's IP pool, and must not overlap subnet_cidr."
  type        = string
  default     = "192.168.0.0/16"
}
