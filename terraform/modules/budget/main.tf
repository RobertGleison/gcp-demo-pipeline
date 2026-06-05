# Monthly cost-alert budget for the trial project. Alerts ONLY — a budget never
# stops spend (the design's deliberate choice; the $300 trial credit is the real
# hard stop). With no all_updates_rule block, GCP emails the billing account's
# admins and users when a threshold is crossed — no monitoring channel needed.

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_billing_budget" "trial" {
  billing_account = var.billing_account
  display_name    = "LoL pipeline - trial cost alerts"

  # Scope the budget to this project only (the billing account may fund others).
  budget_filter {
    projects        = ["projects/${data.google_project.this.number}"]
    calendar_period = "MONTH"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  # One email alert per threshold (against actual current spend).
  dynamic "threshold_rules" {
    for_each = var.threshold_percents
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

}
