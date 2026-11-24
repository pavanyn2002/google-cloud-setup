# Monthly budget with alerts at 50%, 90% and 100% (emails go to billing admins).
# Skipped until billing_account is set, because creating it needs billing permissions.

data "google_project" "this" {}

resource "google_billing_budget" "prod" {
  count = var.billing_account == "" ? 0 : 1

  billing_account = var.billing_account
  display_name    = "tatva-prod monthly budget"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}
