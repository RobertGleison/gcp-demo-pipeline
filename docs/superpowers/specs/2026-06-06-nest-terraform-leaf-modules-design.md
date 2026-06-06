# Nest Terraform leaf modules under their composite parents

**Date:** 2026-06-06
**Branch:** terraform_style_and_docs

## Goal

The module tree is logically two-tier (composites call leaves) but physically
flat. Each leaf module is consumed by exactly one composite, so move each leaf
inside the composite that uses it, and align names. This makes the
parent/child relationship visible on disk and signals that leaves are private
implementation details of their parent, not root-callable modules.

## Layout convention

Direct nesting — leaf sits alongside the parent's own `.tf` files:
`modules/<parent>/<child>/` (source `./child`), **not** the
`modules/<parent>/modules/<child>/` registry convention.

```
modules/
  budget/
  cicd/        main.tf artifact_registry.tf …   + wif_github/
  iam/         main.tf …                        + service_account/
  warehouse/   main.tf iam.tf …                 + bigquery_datasets/
  extraction/  main.tf secret.tf pubsub.tf extractor.tf …  + cloudrun_job/  + pubsub/
```

## Changes

### 1. Directory moves + renames (`git mv`, preserves history)

| From | To |
|------|----|
| `modules/service_account/`   | `modules/iam/service_account/` |
| `modules/bigquery_datasets/` | `modules/warehouse/bigquery_datasets/` |
| `modules/wif_github/`        | `modules/cicd/wif_github/` |
| `modules/cloudrun_job/`      | `modules/ingest/cloudrun_job/` |
| `modules/pubsub_bq/`         | `modules/ingest/pubsub/` |
| `modules/ingest/`            | `modules/extraction/` |

### 2. `source` path rewrites (state-neutral — `source` is not part of the state address)

- `iam/main.tf`: `../service_account` → `./service_account` (×4)
- `warehouse/main.tf`: `../bigquery_datasets` → `./bigquery_datasets` (×3)
- `cicd/main.tf`: `../wif_github` → `./wif_github`
- `extraction/extractor.tf`: `../cloudrun_job` → `./cloudrun_job`
- `extraction/pubsub.tf`: `../pubsub_bq` → `./pubsub`
- `environments/prod/main.tf`: `../../modules/ingest` → `../../modules/extraction`

### 3. Root block rename (the only state-affecting change)

- `environments/prod/main.tf`: `module "ingest"` → `module "extraction"`
- `environments/prod/outputs.tf`: `module.ingest.extractor_job_name` →
  `module.extraction.extractor_job_name`; `module.ingest.topic_id` →
  `module.extraction.topic_id`
- Add a `moved` block in `environments/prod/` so the whole subtree migrates
  without destroy/recreate:

  ```hcl
  moved {
    from = module.ingest
    to   = module.extraction
  }
  ```

Note: the nested block labels are already clean — `extraction/pubsub.tf`
declares `module "pubsub"` and `extractor.tf` declares `module "extractor"`,
so the directory renames need no further `moved` blocks.

### 4. README usage-example touch-ups (docs only)

Update the `source = "../<name>"` example in each moved leaf's README to the
new relative path (`./<name>`), and rename `pubsub_bq`/`ingest` references.

## Verification

`terraform init` then `terraform plan` in `environments/prod/`. Expected:
no resource add/change/destroy — only the single `moved` for the block rename.

## Execution

Claude performs the `git mv` and all edits; user reviews the resulting diff.
