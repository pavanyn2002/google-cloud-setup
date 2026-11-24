variable "project_id" {
  description = "Google Cloud project ID for production."
  type        = string
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zone" {
  description = "Zone of the control plane and first node."
  type        = string
  default     = "asia-south1-a"
}

variable "extra_zones" {
  description = "Second zone for nodes, so one zone failing doesn't take the apps down."
  type        = list(string)
  default     = ["asia-south1-b"]
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "min_nodes_per_zone" {
  type    = number
  default = 1
}

variable "max_nodes_per_zone" {
  type    = number
  default = 2
}

variable "authorized_networks" {
  description = "Optional admin CIDRs for the control plane IP endpoint (kubectl normally uses the DNS endpoint)."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "github_org" {
  type    = string
  default = "tatvaops"
}

variable "github_repos" {
  description = "Repositories allowed to push images."
  type        = list(string)
  default = [
    "tatva-direct",
    "tatvaops-logistic-module",
    "tatva-delivery-partner",
    "tatva-users-micro",
    "tatvaops-admin-micro",
    "tatvaops-vendor-micro",
    "tatvaops-milestone-micro",
    "tatvaops-notification-service",
    "tatvaops-payment-micro",
    "tatvaops-chat-micro",
  ]
}

variable "github_build_refs" {
  description = "Branches whose workflows may push images."
  type        = list(string)
  default     = ["refs/heads/dev", "refs/heads/test", "refs/heads/main"]
}

variable "billing_account" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX) for the budget alert. Leave empty to skip."
  type        = string
  default     = ""
}

variable "budget_amount_usd" {
  type    = number
  default = 250
}
