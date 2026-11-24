# Public entry point for production APIs.
# - one reserved global static IP, used by the GKE Gateway (Google load balancer)
# - a Cloud Armor policy that lets ONLY Cloudflare's edge reach the load balancer
#   (attach it to each app Service with a GCPBackendPolicy; see platform/gke/gateway.yaml)

resource "google_compute_global_address" "gateway" {
  name        = "${var.name}-gateway-ip"
  description = "Static IP for the production Gateway. Cloudflare DNS (proxied) points here."
}

locals {
  # Cloud Armor accepts at most 10 IP ranges per rule.
  cloudflare_chunks = chunklist(var.cloudflare_ranges, 10)
}

resource "google_compute_security_policy" "cloudflare_only" {
  name        = "${var.name}-cloudflare-only"
  description = "Only Cloudflare's edge may reach production APIs"

  dynamic "rule" {
    for_each = local.cloudflare_chunks
    content {
      action      = "allow"
      priority    = 1000 + rule.key
      description = "Cloudflare edge ranges, part ${rule.key + 1}"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value
        }
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 2147483647
    description = "Default: deny everyone else"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
