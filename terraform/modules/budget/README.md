# budget

A monthly **cost-alert budget** for the project. Alerts **only** — a budget never
stops spend. With no `all_updates_rule` block, GCP emails the billing account's
admins and users when a threshold is crossed (no monitoring channel needed).

## Usage

```hcl
module "budget" {
  source = "../../modules/budget"

  project_id         = var.project_id
  billing_account    = var.billing_account
  budget_currency    = "EUR"
  budget_amount      = 200
  threshold_percents = [0.25, 0.5, 1.0]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| google | ~> 6.0 (inherited from the root) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Project whose spend the budget tracks. | `string` | n/a | yes |
| billing_account | Billing account ID that funds the project. | `string` | n/a | yes |
| budget_currency | Currency; must match the billing account. Validated 3-letter ISO code. | `string` | `"EUR"` | no |
| budget_amount | Budget baseline in `budget_currency`. Validated `> 0`. | `number` | `200` | no |
| threshold_percents | Fractions of `budget_amount` at which to alert. Validated each in `(0, 1]`. | `list(number)` | `[0.25, 0.5, 1.0]` | no |

## Outputs

| Name | Description |
|------|-------------|
| budget_id | Resource name of the budget (`billingAccounts/<account>/budgets/<id>`). |
