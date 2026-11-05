variable "project_id" {
  description = "Your Google Cloud project ID."
  type        = string
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zone" {
  type    = string
  default = "asia-south1-a"
}

variable "worker_count" {
  description = "2 workers is enough for 5 small apps; raise it if pods stay Pending."
  type        = number
  default     = 2
}

variable "worker_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "k8s_minor" {
  type    = string
  default = "v1.34"
}
