variable "project_id" {
  type = string
}

variable "name" {
  description = "Cluster name; also the prefix for its node service account."
  type        = string
}

variable "zone" {
  description = "Zone of the control plane and of the first node."
  type        = string
}

variable "extra_zones" {
  description = "Additional zones for nodes (do not repeat var.zone). One node per zone by default."
  type        = list(string)
  default     = []
}

variable "network_self_link" {
  type = string
}

variable "subnet_self_link" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "machine_type" {
  description = "e2-standard-2 = 2 vCPU / 8 GB."
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "min_nodes_per_zone" {
  type    = number
  default = 1
}

variable "max_nodes_per_zone" {
  description = "Hard cap on machines per zone, so a traffic spike can't create a surprise bill."
  type        = number
  default     = 2
}

variable "release_channel" {
  description = "REGULAR gets tested Kubernetes versions automatically, inside the maintenance window."
  type        = string
  default     = "REGULAR"
}

variable "maintenance_start" {
  description = "RFC 3339; only the time of day and duration matter. 20:30 UTC = 02:00 IST."
  type        = string
  default     = "2026-12-01T20:30:00Z"
}

variable "maintenance_end" {
  type    = string
  default = "2026-12-02T00:30:00Z"
}

variable "maintenance_recurrence" {
  description = "Tuesday to Thursday nights only, never before a weekend."
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=TU,WE,TH"
}

variable "authorized_networks" {
  description = "Optional admin networks allowed to the control plane IP endpoint. kubectl normally uses the DNS endpoint with IAM."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "deletion_protection" {
  description = "Must be set to false (and applied) before the cluster can ever be destroyed."
  type        = bool
  default     = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
