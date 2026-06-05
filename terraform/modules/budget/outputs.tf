output "budget_id" {
  description = "Resource name of the budget (billingAccounts/<account>/budgets/<id>)."
  value       = google_billing_budget.trial.id
}
