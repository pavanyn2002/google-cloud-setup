variable "name" {
  description = "Name prefix for the VPC and everything in it."
  type        = string
}

variable "region" {
  type = string
}

variable "subnet_cidr" {
  description = "IP range for the GKE nodes."
  type        = string
  default     = "10.10.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary range for pods. Must not overlap the other ranges."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for Kubernetes services."
  type        = string
  default     = "10.30.0.0/20"
}
