# Terraform single-root refactor — design

**Date:** 2026-06-05
**Status:** Approved (direction); pending spec review
**Branch:** `add_ingestor`

## Goal

Collapse the current 5-layer, 5-state Terraform layout into a **single root** with
**fat modules**. The environment root holds only entry-point + wiring files; all
resource logic lives in `modules/`.

User's framing: _"environments/prod/ should have main.tf, backend.tf and
terraform.tfvars and all the rest should be in modules."_

## Current state (what we're changing)

```
terraform/environments/prod/
  budget/     (apis, backend, main, outputs, providers, variables, versions)
  cicd/       (+ artifact_registry)
  iam/        (4 service accounts)
  warehouse/  (+ data, iam)        ── 3 datasets + dataEditor/dataViewer bindings
  ingest/     (+ data, extractor, pubsub, secret)
  common.tfvars
terraform/modules/
  bigquery_datasets/ cloudrun_job/ pubsub_bq/ service_account/ wif_github/
```

Each layer is **both a root and a resource home**, so each carries ~10 files:
required root boilerplate (`backend`/`providers`/`versions`/`tfvars`) **plus**
resource files. Cross-layer values are passed via `terraform_remote_state`
(`data.tf`), and the GCS bucket name is hardcoded ~10 times.

## Target structure

```
terraform/
  environments/prod/
    backend.tf          # GCS state, single prefix: prod
    providers.tf        # google provider (project, region)
    versions.tf         # tf >= 1.5, google >= 6.0
    apis.tf             # ALL google_project_service, DEDUPLICATED (see Decision 2)
    variables.tf        # input declarations
    main.tf             # calls all 5 modules, wires outputs between them
    outputs.tf          # top-level outputs (CD hand-off: WIF provider, deployer SA, etc.)
    terraform.tfvars    # renamed from common.tfvars

  modules/
    # composition modules — NEW; hold the resource logic moved out of the layers
    budget/             # google_billing_budget
    cicd/               # wif_github + artifact registry repo + deployer writer binding
    iam/                # the 4 service_account module calls
    warehouse/          # 3 bigquery_datasets calls + dataEditor/dataViewer bindings
    ingest/             # matches_bronze table + pubsub_bq + cloudrun_job + secret + topic IAM

    # leaf modules — UNCHANGED, reused by the composition modules
    bigquery_datasets/ cloudrun_job/ pubsub_bq/ service_account/ wif_github/
```

Root drops to ~8 small wiring files **total**; all resource logic lives in modules.

## Cross-module wiring (replaces `data.tf` / remote_state)

`main.tf` passes module outputs directly — no `terraform_remote_state`:

| Producer (output)                    | Consumer(s)                           |
| ------------------------------------ | ------------------------------------- |
| `module.iam.extractor_sa_email`      | `module.ingest`                       |
| `module.iam.scheduler_sa_email`      | `module.ingest`                       |
| `module.iam.pubsub_bq_sa_email`      | `module.ingest`, `module.warehouse`   |
| `module.iam.dbt_sa_email`            | `module.warehouse`                    |
| `module.warehouse.bronze_dataset_id` | `module.ingest`                       |
| `module.cicd.artifact_registry_repo` | `module.ingest` (extractor image URI) |

Implicit dependency ordering comes free from passing these outputs (Terraform
infers `iam` → `warehouse`/`ingest`, etc.). No manual `depends_on` between modules.

## Decisions

### Decision 1 — one root, one state

Single `environments/prod/` → one GCS state (prefix `prod`), one `terraform apply`
for everything. Chosen for simplicity on a small study project. Trade-off
accepted: no blast-radius isolation between foundation (cicd/iam) and pipeline
(ingest); a pipeline change re-plans everything.

### Decision 2 — APIs must be deduplicated (hard requirement)

Across separate states, overlapping `google_project_service` (e.g. `bigquery` in
both warehouse and ingest) was safe. In **one** state, two resources for the same
API is a duplicate-resource error. All APIs collapse into one root `apis.tf`:

```
billingbudgets, cloudbilling, artifactregistry, iam, iamcredentials, sts,
cloudresourcemanager, run, cloudscheduler, pubsub, secretmanager, bigquery
```

Modules `depends_on` the root API enablement (`google_project_service.services`).

### Decision 3 — composition modules don't declare a provider

Each new composition module gets a minimal `versions.tf` (`required_providers`)
but **no** `provider` block — providers are configured once at the root and
inherit down. Leaf modules already follow this.

### Decision 4 — migration: destroy & recreate (no state surgery)

Infra is a disposable study deployment. We destroy via the **current** code
first, then refactor, then apply the new root fresh.

## Migration plan (high level — detailed in the implementation plan)

1. **Destroy first, using current code**, in reverse dependency order:
   `ingest` → `warehouse` → `iam` → `cicd` → `budget`
   (Destroy must run against the state that tracks the resources, before any
   refactor, or the new single-state apply collides on existing names.)
2. **Refactor** the folders into the target structure above.
3. **Apply** the new single root from scratch.
4. **Manual step:** re-add the Riot API key value to the recreated Secret Manager
   secret (the key value is never managed by Terraform).

### Known destroy/recreate caveats

- **BigQuery data** is deleted — disposable by design (bronze self-expires; silver/
  gold are dbt-rebuildable).
- **Artifact Registry images** are deleted — CD re-pushes on next build.
- **Secret value** is deleted — re-pasted by hand (already a manual step).
- **WIF pool/provider + service accounts** are soft-deleted with a ~30-day ID
  reservation. Recreating with identical IDs immediately _can_ hit
  "already exists (soft-deleted)" or a changed unique ID. Usually fine on a fresh
  trial project; if it nags, wait or temporarily rename.

## Out of scope

- No multi-environment (dev/silver) generalization — prod only, as today.
- No Terragrunt / tooling change.
- The planned `dbt`/`transform` workload is not added here; the structure leaves
  room for it (existing `sa-dbt`, reusable `cloudrun_job` module).

## Success criteria

- `environments/prod/` contains only wiring files (no resource definitions).
- `terraform plan` on the single root produces the same resource set that the 5
  layers produced (minus the duplicate API enablement).
- No `terraform_remote_state` blocks remain.
- The GCS bucket name appears once (in `backend.tf`).
- A single `terraform apply` builds the whole project; a single `terraform
destroy` tears it down.
