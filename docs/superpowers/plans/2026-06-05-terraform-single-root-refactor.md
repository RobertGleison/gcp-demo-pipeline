# Terraform Single-Root Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the 5-layer / 5-state Terraform layout into one root (`terraform/environments/prod/`) with fat composition modules, migrating by destroy-then-recreate.

**Architecture:** Each former layer (budget, cicd, iam, warehouse, ingest) becomes a composition module under `terraform/modules/`. The root holds only wiring files (`backend`, `providers`, `versions`, `apis`, `variables`, `main`, `outputs`, `terraform.tfvars`). Cross-layer `terraform_remote_state` lookups are replaced by direct module-output references in `main.tf`. APIs are deduplicated into one root `apis.tf`.

**Tech Stack:** Terraform >= 1.5, hashicorp/google >= 6.0, GCS remote backend, GCP (BigQuery, Cloud Run Jobs, Pub/Sub, Secret Manager, Artifact Registry, WIF, Billing Budgets).

**Spec:** `docs/superpowers/specs/2026-06-05-terraform-single-root-design.md`

## Ordering note (read before executing)

We build and `terraform validate` the new code **first** (it only adds files — it never touches live infra), then **destroy** the old layers, then delete the old folders and **apply** the new root. This honors "destroy before replacing the old code" while letting us catch wiring errors before anything is torn down. The only irreversible step is the destroy in Phase 3; everything it removes is disposable or rebuilt by Phase 4 + Phase 5.

Constants used throughout:

- State bucket: `project-5a3b1a75-500c-4b93-9e1-tfstate`
- New root state prefix: `prod`
- Old layer prefixes: `prod/budget`, `prod/cicd`, `prod/iam`, `prod/warehouse`, `prod/ingest`

---

## Phase 1 — Build the composition modules (no infra change)

### Task 1: Create module skeleton dirs and a shared `versions.tf`

**Files:**

- Create: `terraform/modules/{budget,cicd,iam,warehouse,ingest}/versions.tf`

- [ ] **Step 1: Create the five module directories**

```bash
cd /Users/robertpereira/Desktop/codebase/gcp-demo-pipeline
mkdir -p terraform/modules/budget terraform/modules/cicd terraform/modules/iam terraform/modules/warehouse terraform/modules/ingest
```

- [ ] **Step 2: Write `versions.tf` into each of the five modules**

Identical content for each file (composition modules declare `required_providers` but **no** `provider` block — the provider is configured once at the root and inherits down):

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}
```

Write it to all five:
`terraform/modules/budget/versions.tf`, `terraform/modules/cicd/versions.tf`, `terraform/modules/iam/versions.tf`, `terraform/modules/warehouse/versions.tf`, `terraform/modules/ingest/versions.tf`.

- [ ] **Step 3: Commit**

```bash
git add terraform/modules/budget/versions.tf terraform/modules/cicd/versions.tf terraform/modules/iam/versions.tf terraform/modules/warehouse/versions.tf terraform/modules/ingest/versions.tf
git commit -m "chore(terraform): scaffold composition module dirs"
```

---

### Task 2: Build the `budget` module

**Files:**

- Move: `terraform/environments/prod/budget/{main.tf,variables.tf,outputs.tf}` → `terraform/modules/budget/`

- [ ] **Step 1: Move the resource, variables, and outputs files (preserve history)**

```bash
git mv terraform/environments/prod/budget/main.tf      terraform/modules/budget/main.tf
git mv terraform/environments/prod/budget/variables.tf terraform/modules/budget/variables.tf
git mv terraform/environments/prod/budget/outputs.tf   terraform/modules/budget/outputs.tf
```

- [ ] **Step 2: Remove the API dependency from `terraform/modules/budget/main.tf`**

Delete this line (APIs are now enabled at the root):

```hcl
  depends_on = [google_project_service.budget]
```

The `data "google_project" "this"` block and the `google_billing_budget` resource stay unchanged.

- [ ] **Step 3: Drop the unused `region` variable from `terraform/modules/budget/variables.tf`**

Delete this whole block (the budget module never references `region`):

```hcl
variable "region" {
  description = "Default provider region. Unused by the budget (billing is global) but required by the shared provider block."
  type        = string
}
```

Keep `project_id`, `billing_account`, `budget_currency`, `budget_amount`, `threshold_percents`.

- [ ] **Step 4: Commit**

```bash
git add terraform/modules/budget terraform/environments/prod/budget
git commit -m "refactor(terraform): extract budget composition module"
```

---

### Task 3: Build the `cicd` module

**Files:**

- Move: `terraform/environments/prod/cicd/{main.tf,artifact_registry.tf,variables.tf,outputs.tf}` → `terraform/modules/cicd/`

- [ ] **Step 1: Move the files**

```bash
git mv terraform/environments/prod/cicd/main.tf              terraform/modules/cicd/main.tf
git mv terraform/environments/prod/cicd/artifact_registry.tf terraform/modules/cicd/artifact_registry.tf
git mv terraform/environments/prod/cicd/variables.tf         terraform/modules/cicd/variables.tf
git mv terraform/environments/prod/cicd/outputs.tf           terraform/modules/cicd/outputs.tf
```

- [ ] **Step 2: Fix the leaf-module source path in `terraform/modules/cicd/main.tf`**

Change:

```hcl
  source = "../../../modules/wif_github"
```

to:

```hcl
  source = "../wif_github"
```

- [ ] **Step 3: Remove the API dependency from `terraform/modules/cicd/main.tf`**

Delete this line from the `module "wif_github"` block:

```hcl
  depends_on = [google_project_service.cicd]
```

- [ ] **Step 4: Remove the API dependency from `terraform/modules/cicd/artifact_registry.tf`**

Delete this line from the `google_artifact_registry_repository "images"` resource:

```hcl
  depends_on = [google_project_service.cicd]
```

(`variables.tf` keeps all four vars — `project_id`, `region`, `github_repository`, `artifact_repo_id`. `outputs.tf` is unchanged: it exports `artifact_registry_repo`, `wif_provider_name`, `deployer_sa_email`.)

- [ ] **Step 5: Commit**

```bash
git add terraform/modules/cicd terraform/environments/prod/cicd
git commit -m "refactor(terraform): extract cicd composition module"
```

---

### Task 4: Build the `iam` module

**Files:**

- Move: `terraform/environments/prod/iam/{main.tf,variables.tf,outputs.tf}` → `terraform/modules/iam/`

- [ ] **Step 1: Move the files**

```bash
git mv terraform/environments/prod/iam/main.tf      terraform/modules/iam/main.tf
git mv terraform/environments/prod/iam/variables.tf terraform/modules/iam/variables.tf
git mv terraform/environments/prod/iam/outputs.tf   terraform/modules/iam/outputs.tf
```

- [ ] **Step 2: Fix the leaf-module source path in `terraform/modules/iam/main.tf` (4 occurrences)**

Change every occurrence of:

```hcl
  source = "../../../modules/service_account"
```

to:

```hcl
  source = "../service_account"
```

(There are four `module` blocks: `extractor`, `dbt`, `scheduler`, `pubsub_bq`.)

- [ ] **Step 3: Remove the API dependency from all four module blocks in `terraform/modules/iam/main.tf`**

Delete each occurrence of:

```hcl
  depends_on = [google_project_service.iam]
```

- [ ] **Step 4: Drop the unused `region` variable from `terraform/modules/iam/variables.tf`**

Delete this block (the iam module only uses `project_id`):

```hcl
variable "region" {
  description = "Default provider region. Unused by IAM resources (SAs are global) but required by the shared provider block."
  type        = string
}
```

(`outputs.tf` is unchanged: `extractor_sa_email`, `dbt_sa_email`, `scheduler_sa_email`, `pubsub_bq_sa_email`.)

- [ ] **Step 5: Commit**

```bash
git add terraform/modules/iam terraform/environments/prod/iam
git commit -m "refactor(terraform): extract iam composition module"
```

---

### Task 5: Build the `warehouse` module

**Files:**

- Move: `terraform/environments/prod/warehouse/{main.tf,iam.tf,variables.tf,outputs.tf}` → `terraform/modules/warehouse/`
- Delete: `terraform/environments/prod/warehouse/data.tf` (remote_state, no longer needed)

- [ ] **Step 1: Move the files and delete `data.tf`**

```bash
git mv terraform/environments/prod/warehouse/main.tf      terraform/modules/warehouse/main.tf
git mv terraform/environments/prod/warehouse/iam.tf       terraform/modules/warehouse/iam.tf
git mv terraform/environments/prod/warehouse/variables.tf terraform/modules/warehouse/variables.tf
git mv terraform/environments/prod/warehouse/outputs.tf   terraform/modules/warehouse/outputs.tf
git rm terraform/environments/prod/warehouse/data.tf
```

- [ ] **Step 2: Fix the leaf-module source path in `terraform/modules/warehouse/main.tf` (3 occurrences)**

Change every occurrence of:

```hcl
  source = "../../../modules/bigquery_datasets"
```

to:

```hcl
  source = "../bigquery_datasets"
```

- [ ] **Step 3: Remove the API dependency from the three dataset module blocks in `terraform/modules/warehouse/main.tf`**

Delete each occurrence of:

```hcl
  depends_on = [google_project_service.warehouse]
```

- [ ] **Step 4: Replace remote-state references with input variables in `terraform/modules/warehouse/iam.tf`**

Change the `locals` block from:

```hcl
locals {
  dbt_member       = "serviceAccount:${data.terraform_remote_state.iam.outputs.dbt_sa_email}"
  pubsub_bq_member = "serviceAccount:${data.terraform_remote_state.iam.outputs.pubsub_bq_sa_email}"
}
```

to:

```hcl
locals {
  dbt_member       = "serviceAccount:${var.dbt_sa_email}"
  pubsub_bq_member = "serviceAccount:${var.pubsub_bq_sa_email}"
}
```

(The four `google_bigquery_dataset_iam_member` resources below it stay unchanged.)

- [ ] **Step 5: Update `terraform/modules/warehouse/variables.tf` — drop `region`, add the two injected SA emails**

Delete this block:

```hcl
variable "region" {
  description = "Default provider region. BigQuery uses bq_location instead, but the shared provider block requires this."
  type        = string
}
```

Append these two variables:

```hcl
variable "dbt_sa_email" {
  description = "dbt runtime SA email (from the iam module) — granted dataViewer on bronze and dataEditor on silver/gold."
  type        = string
}

variable "pubsub_bq_sa_email" {
  description = "Pub/Sub->BQ subscription SA email (from the iam module) — granted dataEditor on bronze."
  type        = string
}
```

Keep `project_id`, `bq_location`, `bronze_dataset`, `silver_dataset`, `gold_dataset`. (`outputs.tf` unchanged: `bronze_dataset_id`, `silver_dataset_id`, `gold_dataset_id`.)

- [ ] **Step 6: Commit**

```bash
git add terraform/modules/warehouse terraform/environments/prod/warehouse
git commit -m "refactor(terraform): extract warehouse composition module"
```

---

### Task 6: Build the `ingest` module

**Files:**

- Move: `terraform/environments/prod/ingest/{main.tf,extractor.tf,pubsub.tf,secret.tf,variables.tf,outputs.tf}` → `terraform/modules/ingest/`
- Delete: `terraform/environments/prod/ingest/data.tf` (remote_state, no longer needed)

- [ ] **Step 1: Move the files and delete `data.tf`**

```bash
git mv terraform/environments/prod/ingest/main.tf      terraform/modules/ingest/main.tf
git mv terraform/environments/prod/ingest/extractor.tf terraform/modules/ingest/extractor.tf
git mv terraform/environments/prod/ingest/pubsub.tf    terraform/modules/ingest/pubsub.tf
git mv terraform/environments/prod/ingest/secret.tf    terraform/modules/ingest/secret.tf
git mv terraform/environments/prod/ingest/variables.tf terraform/modules/ingest/variables.tf
git mv terraform/environments/prod/ingest/outputs.tf   terraform/modules/ingest/outputs.tf
git rm terraform/environments/prod/ingest/data.tf
```

- [ ] **Step 2: Replace remote-state references with input variables in `terraform/modules/ingest/main.tf`**

Replace the entire `locals` block:

```hcl
locals {
  # Runtime SA emails from the iam layer.
  extractor_sa_email = data.terraform_remote_state.iam.outputs.extractor_sa_email
  scheduler_sa_email = data.terraform_remote_state.iam.outputs.scheduler_sa_email
  pubsub_bq_sa_email = data.terraform_remote_state.iam.outputs.pubsub_bq_sa_email

  # bronze landing dataset from the warehouse layer.
  bronze_dataset_id = data.terraform_remote_state.warehouse.outputs.bronze_dataset_id

  # Extractor image: <region>-docker.pkg.dev/<project>/pipeline-images + /extractor:<tag>.
  # The repo prefix comes from the cicd layer; CD must have pushed this tag first.
  extractor_image = "${data.terraform_remote_state.cicd.outputs.artifact_registry_repo}/extractor:${var.extractor_image_tag}"
}
```

with:

```hcl
locals {
  # Runtime SA emails injected from the iam module.
  extractor_sa_email = var.extractor_sa_email
  scheduler_sa_email = var.scheduler_sa_email
  pubsub_bq_sa_email = var.pubsub_bq_sa_email

  # bronze landing dataset injected from the warehouse module.
  bronze_dataset_id = var.bronze_dataset_id

  # Extractor image: <repo-prefix>/extractor:<tag>. Repo prefix injected from the
  # cicd module; CD must have pushed this tag first.
  extractor_image = "${var.artifact_registry_repo}/extractor:${var.extractor_image_tag}"
}
```

- [ ] **Step 3: Fix leaf-module source paths and drop API deps in `terraform/modules/ingest/extractor.tf`**

Change:

```hcl
  source = "../../../modules/cloudrun_job"
```

to:

```hcl
  source = "../cloudrun_job"
```

And delete this line from the `module "extractor"` block:

```hcl
  depends_on = [google_project_service.ingest]
```

- [ ] **Step 4: Fix leaf-module source path and prune API deps in `terraform/modules/ingest/pubsub.tf`**

Change:

```hcl
  source = "../../../modules/pubsub_bq"
```

to:

```hcl
  source = "../pubsub_bq"
```

In the `google_bigquery_table "matches_bronze"` resource, delete its trailing dependency line:

```hcl
  depends_on = [google_project_service.ingest]
```

In the `module "pubsub"` block, change its `depends_on` from:

```hcl
  depends_on = [
    google_bigquery_table.matches_bronze,
    google_project_service.ingest,
  ]
```

to:

```hcl
  depends_on = [
    google_bigquery_table.matches_bronze,
  ]
```

(The `google_pubsub_topic_iam_member "extractor_publisher"` resource is unchanged.)

- [ ] **Step 5: Drop the API dep in `terraform/modules/ingest/secret.tf`**

Delete this line from the `google_secret_manager_secret "riot_api_key"` resource:

```hcl
  depends_on = [google_project_service.ingest]
```

(The `google_secret_manager_secret_iam_member "extractor_accessor"` resource is unchanged.)

- [ ] **Step 6: Add the five injected variables to `terraform/modules/ingest/variables.tf`**

Append these blocks (keep all existing variables — `project_id`, `region`, `topic_name`, `bronze_table_id`, `bronze_partition_expiration_days`, `extractor_image_tag`, `extractor_args`, `riot_regional_host`, `riot_secret_id`, `schedule_cron`, `schedule_time_zone`):

```hcl
# --- Injected from sibling modules (wired in the root main.tf) ----------------

variable "extractor_sa_email" {
  description = "Extractor runtime SA email (from the iam module)."
  type        = string
}

variable "scheduler_sa_email" {
  description = "Cloud Scheduler SA email (from the iam module)."
  type        = string
}

variable "pubsub_bq_sa_email" {
  description = "Pub/Sub->BQ subscription writer SA email (from the iam module)."
  type        = string
}

variable "bronze_dataset_id" {
  description = "bronze landing dataset ID (from the warehouse module)."
  type        = string
}

variable "artifact_registry_repo" {
  description = "Artifact Registry image path prefix (from the cicd module)."
  type        = string
}
```

(`outputs.tf` is unchanged — it references `module.*`, `local.bronze_dataset_id`, and resources that all move with it.)

- [ ] **Step 7: Commit**

```bash
git add terraform/modules/ingest terraform/environments/prod/ingest
git commit -m "refactor(terraform): extract ingest composition module"
```

---

## Phase 2 — Build the root and validate (no infra change)

### Task 7: Create the single root configuration

**Files:**

- Create: `terraform/environments/prod/{backend.tf,providers.tf,versions.tf,apis.tf,variables.tf,main.tf,outputs.tf,terraform.tfvars}`
- Delete (later, Task 10): `terraform/environments/prod/common.tfvars` and the now-empty old layer dirs

- [ ] **Step 1: Write `terraform/environments/prod/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    bucket = "project-5a3b1a75-500c-4b93-9e1-tfstate"
    prefix = "prod"
  }
}
```

- [ ] **Step 2: Write `terraform/environments/prod/providers.tf`**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}
```

- [ ] **Step 3: Write `terraform/environments/prod/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}
```

- [ ] **Step 4: Write `terraform/environments/prod/apis.tf`** (the deduplicated union of every former layer's APIs — required because one state cannot enable the same API twice)

```hcl
# Every API the project needs, enabled once. In a single state, two
# google_project_service resources for the same API would collide — so the
# previously per-layer lists are merged and deduplicated here. Modules depend on
# this via depends_on in main.tf.
locals {
  project_apis = [
    "billingbudgets.googleapis.com",      # budget
    "cloudbilling.googleapis.com",         # budget
    "artifactregistry.googleapis.com",     # cicd
    "iam.googleapis.com",                  # cicd + iam
    "iamcredentials.googleapis.com",       # cicd (WIF)
    "sts.googleapis.com",                  # cicd (WIF)
    "cloudresourcemanager.googleapis.com", # cicd + iam
    "run.googleapis.com",                  # ingest
    "cloudscheduler.googleapis.com",       # ingest
    "pubsub.googleapis.com",               # ingest
    "secretmanager.googleapis.com",        # ingest
    "bigquery.googleapis.com",             # warehouse + ingest
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.project_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
```

- [ ] **Step 5: Write `terraform/environments/prod/variables.tf`** (union of every layer's input variables)

```hcl
# --- Project-wide -------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (Cloud Run, Scheduler, Pub/Sub, Artifact Registry)."
  type        = string
}

# --- Budget -------------------------------------------------------------------
variable "billing_account" {
  description = "Billing account ID that funds the project."
  type        = string
}

variable "budget_currency" {
  description = "Currency for the budget amount; must match the billing account's currency."
  type        = string
  default     = "EUR"
}

variable "budget_amount" {
  description = "Budget baseline in budget_currency."
  type        = number
  default     = 200
}

variable "threshold_percents" {
  description = "Fractions of budget_amount at which to alert."
  type        = list(number)
  default     = [0.25, 0.5, 1.0]
}

# --- CI/CD --------------------------------------------------------------------
variable "github_repository" {
  description = "GitHub repo allowed to push images via WIF, as owner/repo."
  type        = string
}

variable "artifact_repo_id" {
  description = "Artifact Registry repository ID (Docker format)."
  type        = string
  default     = "pipeline-images"
}

# --- Warehouse ----------------------------------------------------------------
variable "bq_location" {
  description = "BigQuery dataset location (e.g. multi-region \"US\")."
  type        = string
}

variable "bronze_dataset" {
  description = "Dataset ID for the bronze landing zone."
  type        = string
  default     = "bronze"
}

variable "silver_dataset" {
  description = "Dataset ID for silver dbt silver models."
  type        = string
  default     = "silver"
}

variable "gold_dataset" {
  description = "Dataset ID for gold dbt gold."
  type        = string
  default     = "gold"
}

# --- Ingest -------------------------------------------------------------------
variable "topic_name" {
  description = "Main topic the extractor publishes matches to."
  type        = string
  default     = "lol-matches"
}

variable "bronze_table_id" {
  description = "Landing table in the bronze dataset the BigQuery subscription writes to."
  type        = string
  default     = "matches_bronze"
}

variable "bronze_partition_expiration_days" {
  description = "Days a daily partition of matches_bronze is kept before BigQuery drops it."
  type        = number
  default     = 30
}

variable "extractor_image_tag" {
  description = "Tag of the extractor image in Artifact Registry to deploy."
  type        = string
  default     = "latest"
}

variable "extractor_args" {
  description = "Container args passed to the extractor each run."
  type        = list(string)
  default     = ["--count", "10"]
}

variable "riot_regional_host" {
  description = "Riot regional routing host for match-v5 / account-v1."
  type        = string
  default     = "https://americas.api.riotgames.com"
}

variable "riot_secret_id" {
  description = "Secret Manager secret ID holding the Riot API key (value added by hand)."
  type        = string
  default     = "riot-api-key"
}

variable "schedule_cron" {
  description = "Unix-cron schedule for the extractor trigger."
  type        = string
  default     = "*/30 * * * *"
}

variable "schedule_time_zone" {
  description = "IANA time zone the cron schedule is interpreted in."
  type        = string
  default     = "Etc/UTC"
}
```

- [ ] **Step 6: Write `terraform/environments/prod/main.tf`** (calls every module; wires outputs between them; each module depends on the root API enablement)

```hcl
# Single-root composition. Each module owns one former layer; cross-module values
# are passed directly (no terraform_remote_state). Every module depends on the
# project APIs enabled in apis.tf.

module "budget" {
  source = "../../modules/budget"

  project_id         = var.project_id
  billing_account    = var.billing_account
  budget_currency    = var.budget_currency
  budget_amount      = var.budget_amount
  threshold_percents = var.threshold_percents

  depends_on = [google_project_service.services]
}

module "cicd" {
  source = "../../modules/cicd"

  project_id        = var.project_id
  region            = var.region
  github_repository = var.github_repository
  artifact_repo_id  = var.artifact_repo_id

  depends_on = [google_project_service.services]
}

module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  depends_on = [google_project_service.services]
}

module "warehouse" {
  source = "../../modules/warehouse"

  project_id      = var.project_id
  bq_location     = var.bq_location
  bronze_dataset     = var.bronze_dataset
  silver_dataset = var.silver_dataset
  gold_dataset   = var.gold_dataset

  # Injected from iam (dataset-scoped role bindings live with the dataset).
  dbt_sa_email       = module.iam.dbt_sa_email
  pubsub_bq_sa_email = module.iam.pubsub_bq_sa_email

  depends_on = [google_project_service.services]
}

module "ingest" {
  source = "../../modules/ingest"

  project_id                    = var.project_id
  region                        = var.region
  topic_name                    = var.topic_name
  bronze_table_id                  = var.bronze_table_id
  bronze_partition_expiration_days = var.bronze_partition_expiration_days
  extractor_image_tag           = var.extractor_image_tag
  extractor_args                = var.extractor_args
  riot_regional_host            = var.riot_regional_host
  riot_secret_id                = var.riot_secret_id
  schedule_cron                 = var.schedule_cron
  schedule_time_zone            = var.schedule_time_zone

  # Injected from sibling modules.
  extractor_sa_email     = module.iam.extractor_sa_email
  scheduler_sa_email     = module.iam.scheduler_sa_email
  pubsub_bq_sa_email     = module.iam.pubsub_bq_sa_email
  bronze_dataset_id         = module.warehouse.bronze_dataset_id
  artifact_registry_repo = module.cicd.artifact_registry_repo

  depends_on = [google_project_service.services]
}
```

- [ ] **Step 7: Write `terraform/environments/prod/outputs.tf`** (surface the CD hand-off values)

```hcl
output "artifact_registry_repo" {
  description = "Image path prefix: <region>-docker.pkg.dev/<project>/<repo>."
  value       = module.cicd.artifact_registry_repo
}

output "wif_provider_name" {
  description = "Full WIF provider resource name — set as GitHub Actions var GCP_WIF_PROVIDER."
  value       = module.cicd.wif_provider_name
}

output "deployer_sa_email" {
  description = "Deployer SA email — set as GitHub Actions var GCP_DEPLOYER_SA."
  value       = module.cicd.deployer_sa_email
}
```

- [ ] **Step 8: Write `terraform/environments/prod/terraform.tfvars`** (same values as the old `common.tfvars`)

```hcl
# Root inputs for the prod environment.
project_id        = "project-5a3b1a75-500c-4b93-9e1"
region            = "us-central1"
github_repository = "RobertGleison/gcp-demo-pipeline"
billing_account   = "016260-E54BF6-671DF7"

# Warehouse
bq_location     = "US"
bronze_dataset     = "bronze"
silver_dataset = "silver"
gold_dataset   = "gold"

# Ingest
topic_name         = "lol-matches"
bronze_table_id       = "matches_bronze"
riot_regional_host = "https://americas.api.riotgames.com"
schedule_cron      = "*/30 * * * *"
```

- [ ] **Step 9: Commit**

```bash
git add terraform/environments/prod/backend.tf terraform/environments/prod/providers.tf terraform/environments/prod/versions.tf terraform/environments/prod/apis.tf terraform/environments/prod/variables.tf terraform/environments/prod/main.tf terraform/environments/prod/outputs.tf terraform/environments/prod/terraform.tfvars
git commit -m "feat(terraform): add single-root prod configuration"
```

---

### Task 8: Format and validate the new root (verification gate)

**Files:** none (validation only)

- [ ] **Step 1: Check formatting across the whole terraform tree**

Run:

```bash
cd /Users/robertpereira/Desktop/codebase/gcp-demo-pipeline
terraform fmt -recursive terraform/
```

Expected: prints the names of any reformatted files (or nothing). Review the diff; the moved files should be unchanged apart from alignment.

- [ ] **Step 2: Initialize the new root**

Run:

```bash
terraform -chdir=terraform/environments/prod init
```

Expected: `Terraform has been successfully initialized!`. It downloads the google provider and reads the empty `prod` state prefix (no resources yet).

- [ ] **Step 3: Validate the configuration**

Run:

```bash
terraform -chdir=terraform/environments/prod validate
```

Expected: `Success! The configuration is valid.`
If it reports an undefined variable, unresolved module output, or bad source path, fix it in the relevant module/root file before continuing. **Do not proceed to Phase 3 until validate passes.**

- [ ] **Step 4: Commit any formatting changes**

```bash
git add -A terraform/
git commit -m "style(terraform): terraform fmt" || echo "nothing to commit"
```

---

## Phase 3 — Destroy the existing infrastructure

> Irreversible step. Everything torn down here is rebuilt in Phase 4, except the Riot secret value (re-added in Phase 5). Destroy in **reverse dependency order**, each against its own existing state.

### Task 9: Verify auth, then destroy the five old layers

**Files:** none (infra teardown)

- [ ] **Step 1: Verify GCP credentials and target project**

Run:

```bash
gcloud config get-value project
gcloud auth application-default print-access-token >/dev/null && echo "ADC OK"
```

Expected: prints the project, then `ADC OK`. If ADC fails, run `gcloud auth application-default login` (suggest the user run `! gcloud auth application-default login` in the session) before continuing.

- [ ] **Step 2: Destroy the `ingest` layer**

Run:

```bash
terraform -chdir=terraform/environments/prod/ingest init
terraform -chdir=terraform/environments/prod/ingest destroy -var-file=../common.tfvars
```

Review the plan (it should destroy the Cloud Run job, scheduler, topic+DLQ+subscriptions, matches_bronze table, secret + IAM, topic IAM), type `yes`.
Expected: `Destroy complete! Resources: N destroyed.`

- [ ] **Step 3: Destroy the `warehouse` layer**

Run:

```bash
terraform -chdir=terraform/environments/prod/warehouse init
terraform -chdir=terraform/environments/prod/warehouse destroy -var-file=../common.tfvars
```

Review (3 datasets + dataset IAM bindings; **dataset data is deleted**), type `yes`.
Expected: `Destroy complete!`

- [ ] **Step 4: Destroy the `iam` layer**

Run:

```bash
terraform -chdir=terraform/environments/prod/iam init
terraform -chdir=terraform/environments/prod/iam destroy -var-file=../common.tfvars
```

Review (4 service accounts), type `yes`.
Expected: `Destroy complete!`

- [ ] **Step 5: Destroy the `cicd` layer**

Run:

```bash
terraform -chdir=terraform/environments/prod/cicd init
terraform -chdir=terraform/environments/prod/cicd destroy -var-file=../common.tfvars
```

Review (WIF pool/provider, deployer SA, Artifact Registry repo — **pushed images deleted**), type `yes`.
Expected: `Destroy complete!`

- [ ] **Step 6: Destroy the `budget` layer**

Run:

```bash
terraform -chdir=terraform/environments/prod/budget init
terraform -chdir=terraform/environments/prod/budget destroy -var-file=../common.tfvars
```

Review (1 billing budget), type `yes`.
Expected: `Destroy complete!`

(No commit — this step changes infra, not code.)

---

## Phase 4 — Remove old layer code and apply the new root

### Task 10: Delete the old layer folders and shared tfvars

**Files:**

- Delete: `terraform/environments/prod/{budget,cicd,iam,warehouse,ingest}/` (leftover boilerplate: `apis.tf`, `backend.tf`, `providers.tf`, `versions.tf`, and the `.terraform/` dirs)
- Delete: `terraform/environments/prod/common.tfvars`

- [ ] **Step 1: Remove the old layer directories and `common.tfvars`**

The resource files were already moved by Phase 1; what remains in each old layer dir is the per-layer boilerplate (`apis.tf`, `backend.tf`, `providers.tf`, `versions.tf`) plus local `.terraform/` cache.

```bash
cd /Users/robertpereira/Desktop/codebase/gcp-demo-pipeline
git rm -r terraform/environments/prod/budget terraform/environments/prod/cicd terraform/environments/prod/iam terraform/environments/prod/warehouse terraform/environments/prod/ingest
rm -f terraform/environments/prod/common.tfvars && git rm --cached terraform/environments/prod/common.tfvars 2>/dev/null || true
```

- [ ] **Step 2: Verify the prod root now contains only wiring files**

Run:

```bash
ls terraform/environments/prod
```

Expected (plus the `.terraform/` cache dir from Task 8): `apis.tf  backend.tf  main.tf  outputs.tf  providers.tf  terraform.tfvars  variables.tf  versions.tf`

- [ ] **Step 3: Commit**

```bash
git add -A terraform/environments/prod
git commit -m "refactor(terraform): remove old per-layer roots and common.tfvars"
```

---

### Task 11: Apply the new single root

**Files:** none (infra build)

- [ ] **Step 1: Plan the new root**

Run:

```bash
terraform -chdir=terraform/environments/prod plan
```

(`terraform.tfvars` is auto-loaded — no `-var-file` needed.)
Expected: a plan that **creates** every resource (budget, WIF pool/provider, deployer SA + Artifact Registry, 4 service accounts, 3 datasets + bindings, topic/DLQ/subscription, matches_bronze table, Cloud Run job + scheduler, secret + IAM, 12 `google_project_service`) and **destroys nothing**. Review the count looks like the union of the old layers.

- [ ] **Step 2: Apply**

Run:

```bash
terraform -chdir=terraform/environments/prod apply
```

Type `yes`.
Expected: `Apply complete!`.

**If WIF pool/provider or a service account fails with "already exists" / soft-deleted:** the prior resource is in GCP's ~30-day soft-delete window. Either wait and re-apply, or `terraform -chdir=terraform/environments/prod apply` after undeleting via `gcloud iam service-accounts undelete` / the WIF pool's parent, or temporarily change the conflicting ID. Note the resolution in the commit message if you change an ID.

(No commit — infra build.)

---

## Phase 5 — Finalize

### Task 12: Re-add the Riot secret value and verify outputs

**Files:** none

- [ ] **Step 1: Add the Riot API key value to the recreated secret**

The secret resource is created empty by Terraform; add a version by hand (suggest the user run it in-session with `!`):

```bash
printf '%s' 'YOUR_RIOT_API_KEY' | gcloud secrets versions add riot-api-key --data-file=- --project=project-5a3b1a75-500c-4b93-9e1
```

Expected: `Created version [1] of the secret [riot-api-key].`

- [ ] **Step 2: Confirm the CD hand-off outputs resolve**

Run:

```bash
terraform -chdir=terraform/environments/prod output
```

Expected: non-empty `artifact_registry_repo`, `wif_provider_name`, `deployer_sa_email`.

- [ ] **Step 3: Sanity-check the full state is in the single prefix**

Run:

```bash
terraform -chdir=terraform/environments/prod state list | head -n 40
```

Expected: resources from all five former layers listed under `module.budget.*`, `module.cicd.*`, `module.iam.*`, `module.warehouse.*`, `module.ingest.*`, plus `google_project_service.services[...]`.

- [ ] **Step 4: (Optional) Clean up the orphaned old state objects**

The old prefixes (`prod/budget`, `prod/cicd`, `prod/iam`, `prod/warehouse`, `prod/ingest`) now hold empty state. Optionally delete them:

```bash
gsutil rm -r gs://project-5a3b1a75-500c-4b93-9e1-tfstate/prod/budget gs://project-5a3b1a75-500c-4b93-9e1-tfstate/prod/cicd gs://project-5a3b1a75-500c-4b93-9e1-tfstate/prod/iam gs://project-5a3b1a75-500c-4b93-9e1-tfstate/prod/warehouse gs://project-5a3b1a75-500c-4b93-9e1-tfstate/prod/ingest
```

Expected: removes the leftover empty state files. (Skip if unsure — empty state is harmless.)

---

## Self-review notes

- **Spec coverage:** thin root (Task 7) ✓; fat composition modules (Tasks 2–6) ✓; APIs deduplicated into one root `apis.tf` (Task 7 Step 4) ✓; remote_state replaced by module outputs (Tasks 5, 6, 7) ✓; destroy-then-recreate in reverse order (Task 9) ✓; manual Riot secret re-add (Task 12) ✓; one state / one apply (Tasks 7, 11) ✓.
- **`region` variable:** dropped from `budget` and `iam` modules (unused there), kept in `cicd` and `ingest` (used), kept at root (provider config). Verified against each module's resource references.
- **Source-path rewrites:** every composition module sits at `terraform/modules/<name>/`, so leaf-module sources change from `../../../modules/<leaf>` to `../<leaf>`. Root-to-composition sources are `../../modules/<name>`.
