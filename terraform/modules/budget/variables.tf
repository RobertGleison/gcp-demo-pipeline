variable "project_id" {
  description = "GCP project ID whose spend the budget tracks."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID (e.g. 016260-E54BF6-671DF7) that funds the project. Managing a budget needs billing.budgets.editor on this account."
  type        = string
}

variable "budget_currency" {
  description = "Currency for the budget amount. MUST match the billing account's own currency, or the API rejects it with 400 INVALID_ARGUMENT. This account is EUR (the design doc's \"$\" figures are nominal)."
  type        = string
  default     = "EUR"

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.budget_currency))
    error_message = "budget_currency must be a 3-letter ISO 4217 code, e.g. \"EUR\"."
  }
}

variable "budget_amount" {
  description = "Budget baseline in budget_currency. Threshold percentages are taken against this — with the defaults, 100% = this value."
  type        = number
  default     = 200

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be greater than 0."
  }
}

variable "threshold_percents" {
  description = "Fractions of budget_amount at which to alert. Defaults map to 50 / 100 / 200 against a 200 baseline."
  type        = list(number)
  default     = [0.25, 0.5, 1.0]

  # Fractions, not percentages — guards against passing e.g. 50 instead of 0.5.
  validation {
    condition     = length(var.threshold_percents) > 0 && alltrue([for p in var.threshold_percents : p > 0 && p <= 1])
    error_message = "threshold_percents must be a non-empty list of fractions in (0, 1] (e.g. 0.5 for 50%)."
  }
}
