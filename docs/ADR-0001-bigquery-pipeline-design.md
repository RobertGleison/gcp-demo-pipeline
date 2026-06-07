# League of Legends → BigQuery Pipeline — Design Spec

**Date:** 2026-06-04
**Status:** Approved design — revised to dbt-core + GitHub Actions CD (implementation not yet started)
**Author:** Robert Pereira

## Purpose

Build a Terraform-provisioned GCP data pipeline that extracts League of
Legends match data from the Riot Games API, ingests it through Pub/Sub, lands it
in BigQuery, transforms JSON into a columnar star schema via **ELT with dbt**, and
serves a Looker Studio dashboard. "Terraform-provisioned" covers the
infrastructure; container images are built by a **GitHub Actions CD pipeline**; a
few data/content steps are deliberately manual (see **Manual / out-of-band
steps**).

The project's primary goal is **hands-on practice for the GCP Professional Data
Engineer certification**, using a $300 free-trial account. Architectural choices
favor exam-relevant services and tight cost control over production realism — with
one deliberate exception (dbt over Dataform, see below) made for real-world
transferability.

## Goals

- Exercise the canonical DE stack: Pub/Sub, BigQuery, ELT, scheduling, IAM,
  partitioning/clustering, Infrastructure as Code, and a CI/CD image pipeline.
- Stay comfortably inside the $300 trial (target: a few dollars total).
- End-to-end reproducibility via Terraform + reproducible, versioned container
  images.

## Non-Goals

- Production-grade reliability or real-time SLAs.
- Always-on streaming (explicitly excluded for cost — see below).
- Comprehensive coverage of every Riot API endpoint.

## Run Mode

**Scheduled batch bursts.** Cloud Scheduler triggers both the extractor and the
dbt transform on cron intervals (default every 30 min, independent clocks).
Compute scales to zero between runs. No always-on workers.

## Project & Region

Single GCP project, single region. Defaults: **`us-central1`** for Cloud Run,
Scheduler, Pub/Sub, and Artifact Registry; BigQuery dataset location **`US`**
(multi-region). These must stay aligned — a Pub/Sub **BigQuery subscription cannot
write across regions**, and the dbt Cloud Run Job must target the same BQ
location. The region/location live in `common.tfvars`.

## Why dbt-core (instead of Dataform)

The transform layer runs **dbt-core in a container**, not Dataform. Dataform is
the GCP-native choice and is fine for the exam, but **dbt is the industry standard
and is portable** (the same models run on Snowflake/Redshift/Databricks). Running
dbt as a container also **reuses the exact extractor pattern** (Cloud Run Job +
Artifact Registry + Cloud Scheduler), reinforcing it, and the GitHub Actions CD
pipeline that builds the image is itself exam/real-world-relevant. The tradeoff is
slightly more plumbing (a second image + a CD pipeline) for a much more
transferable skill. Dataform remains a possible future study module.

## Architecture

```
        GitHub repo  (extractor/  +  dbt/)
              │  push → GitHub Actions CD  (Workload Identity Federation, keyless)
              │  build + push 2 images
              ▼
        Artifact Registry ──────────────┬───────────────────────────┐
              │  pull image              │  pull image                │
              ▼                          ▼                            │
  Cloud Scheduler ─(30m)─▶ Cloud Run Job│  Cloud Scheduler ─(30m)─▶ Cloud Run Job
        (extractor, Python)             │        (dbt, "dbt build")  │
        reads Riot key (Secret Manager) │        BQ auth via SA      │
              │ publish 1 msg/match      │              │             │
              ▼                          │              │ builds      │
       Pub/Sub topic ──▶ Dead-letter    │              │             │
              │  BigQuery subscription   │              ▼             ▼
              │  (no code)               │   silver.* (silver) ──▶ gold.* (gold)
              ▼                          │        partitioned + clustered, MERGE
       BigQuery bronze.matches_bronze ─────────┘              │
              (bronze: bronze JSON)                        ▼
                                              Looker Studio dashboard (free)
```

### Components

| Layer     | Service                                         | Rationale                                                                                                                                                       |
| --------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trigger   | Cloud Scheduler (×2)                            | Cron-driven bursts, ~free. Two independent triggers: one for the extractor job, one for the dbt job. Each triggers its job via `sa-scheduler` (`run.jobs.run`). |
| Extract   | Cloud Run Job (Python)                          | Calls Riot API, publishes to Pub/Sub. Scales to zero.                                                                                                           |
| CI/CD     | GitHub Actions + Workload Identity Federation   | Builds & pushes **both** container images (extractor + dbt) to Artifact Registry on push. Keyless auth — no SA JSON keys.                                       |
| Image     | Artifact Registry                               | Hosts both container images; CD pushes them before the `ingest`/`transform` applies.                                                                            |
| Secrets   | Secret Manager                                  | Holds the Riot API key only. (dbt needs no secret — models are baked into the image and it auths to BQ via its SA.)                                             |
| Ingest    | Pub/Sub (topic + DLQ)                           | Mandatory; decouples extract from load. At-least-once delivery.                                                                                                 |
| Land      | Pub/Sub → BigQuery subscription                 | Writes bronze JSON straight to BQ, no code/Dataflow.                                                                                                            |
| Transform | **dbt-core on Cloud Run Job** (ELT in BigQuery) | JSON → typed star schema, incremental MERGE, dbt tests.                                                                                                         |
| Warehouse | BigQuery                                        | Mandatory; partitioned + clustered gold.                                                                                                                        |
| Serve     | Looker Studio                                   | Free dashboards on the gold.                                                                                                                                    |
| IaC       | Terraform (+ GCS remote state)                  | Provisions everything, least-privilege IAM, budget alert, WIF.                                                                                                  |

### Deliberately excluded

- **Dataflow** — burns budget even in bursts; ELT in BigQuery was chosen instead.
  May be added later as an optional study module.
- **Cloud Composer / Airflow** — ~$300+/mo always-on would consume the whole
  trial. Cloud Scheduler covers orchestration cheaply.
- **Dataform** — viable and GCP-native, but dbt-core was chosen for portability
  and industry relevance (see _Why dbt-core_). Possible future module.

## Data Flow

### Extractor (Cloud Run Job, each schedule tick)

1. Read a small **seed list** of players as **Riot IDs** (`gameName#tagLine`) from
   config — e.g. 5–20 tracked accounts. Default region: `americas` routing / `na1`
   platform (configurable). Summoner-name lookup is deprecated, so resolve each
   Riot ID → PUUID via `account-v1` (by-riot-id) first.
2. For each PUUID: call `match-v5` for recent match IDs (last N, e.g. 10).
3. Skip match IDs already seen (lookup against a small `seen_matches` table or
   the gold) to limit API calls and duplicates.
4. For each new match: fetch full match JSON, publish one Pub/Sub message with
   the bronze JSON body + attributes (`match_id`, `platform`, `queue_id`).
5. Respect Riot rate limits (token-bucket / sleep). On Riot 4xx/5xx: log and
   continue — never crash the whole run.

### Landing — `bronze.matches_bronze` (bronze)

Written by the Pub/Sub BigQuery subscription using the standard schema:
`subscription_name`, `message_id`, `publish_time`, `attributes` (JSON),
`data` (JSON string = full match). Partitioned by ingest date; 30-day
expiration (bronze is disposable — it's the replayable source of truth).

### Transform — dbt medallion model

dbt-core runs inside a container on a Cloud Run Job (`dbt build` = run models +
run tests, in DAG order). Models live in `dbt/` and are baked into the image.
dbt authenticates to BigQuery with the Cloud Run Job's service account
(`profiles.yml` uses `method: oauth` / ADC — no key files).

- **silver.stg_matches** (silver) — parse `data` with `JSON_VALUE` /
  `JSON_QUERY`: one row per match (`match_id`, `game_start`, `game_duration`,
  `queue_id`, `patch`, `winning_team`).
- **silver.stg_participants** (silver) — `UNNEST` the 10 participants: one row
  per (match, player) with champion, role, K/D/A, gold, damage, win flag, etc.
- **gold.dim_champion**, **gold.dim_player** (gold) — small dimension tables.
- **gold.fct_match_participants** (gold) — fact table,
  `materialized='incremental'`, `incremental_strategy='merge'`,
  `unique_key=['match_id','participant_id']`, **partitioned by `game_date`**
  (`require_partition_filter=true`), **clustered by `champion_id, queue_id`**. The
  incremental block selects new rows from `bronze` using a **`publish_time`
  watermark** (`{% if is_incremental() %} where publish_time > (select
max(publish_time) from {{ this }}) {% endif %}`) → idempotent, re-run safe, no
  dupes.

**How the dbt SQL gets deployed:** the `dbt/` directory in the GitHub repo is the
source of truth. On push, **GitHub Actions builds a container image** (dbt-core +
`dbt-bigquery` + the compiled project) and pushes it to Artifact Registry. The
`transform` Terraform layer wires a Cloud Run Job to that image URI. Models change
→ new image → next scheduled run picks it up. No runtime git pull, no PAT.

**How the transform is triggered:** a dedicated Cloud Scheduler job runs the dbt
Cloud Run Job on its own cron (default every 30 min), independent of the
extractor. End-to-end freshness is therefore the max of the extractor and dbt
intervals. (The optional Cloud Workflows module in _Future_ would chain them into
one DAG.)

### Serving — Looker Studio

Dashboards on the gold: win rate by champion, KDA distributions, gold/damage
curves, game-duration trends, per-player scorecards.

**Gotcha:** because `fct_match_participants` has **require-partition-filter**
enabled, every Looker Studio query must include a `game_date` filter — build the
report with a date-range control bound to `game_date`, or queries error. Dimension
tables are unpartitioned and unaffected.

## Repository Layout

The IaC structure is **plain Terraform organized in the spirit of the company's
`infrastructure-live` (Terragrunt) repo**: reusable `modules/` separated from
per-environment "live" config, and **each pipeline layer owns its own state file**
for blast-radius isolation. Terragrunt itself was considered but rejected — with a
single env/region/project its DRY machinery is overhead, and plain Terraform keeps
the workflow closest to a vanilla Data Engineer exam toolchain.

```
gcp-demo-pipeline/
├── .github/workflows/             # GitHub Actions CD: build + push images (keyless via WIF)
│   ├── build-extractor.yml
│   └── build-dbt.yml
├── modules/                       # reusable building blocks (no state of their own)
│   ├── service_account/           # SA + scoped role bindings
│   ├── pubsub_bq/                 # topic + DLQ + BigQuery subscription
│   ├── bigquery_datasets/         # bronze / silver / gold datasets, partition/cluster
│   ├── cloudrun_job/              # generic Cloud Run Job + Scheduler trigger (used by extractor & dbt)
│   └── wif_github/                # Workload Identity pool/provider + deployer SA for GitHub Actions
├── envs/
│   └── dev/                       # the only environment (one GCP project)
│       ├── common.tfvars          # project_id, region, dataset names, schedule, seed players
│       ├── bootstrap/             # one-time: GCS state bucket, enable APIs, budget alerts, Artifact Registry repo, WIF
│       ├── iam/                   # runtime service accounts → outputs SA emails
│       ├── warehouse/             # BigQuery datasets (reads iam state)
│       ├── ingest/                # Pub/Sub + BQ subscription + extractor job (reads iam + warehouse)
│       └── transform/             # dbt Cloud Run Job + Scheduler (reads iam + warehouse)
├── extractor/                     # Python Cloud Run Job source + Dockerfile
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── dbt/                           # dbt project (baked into the dbt image by CD)
│   ├── dbt_project.yml
│   ├── profiles.yml               # BigQuery, method: oauth (ADC), no keyfile
│   ├── models/
│   │   ├── silver/               # stg_matches, stg_participants (silver)
│   │   └── gold/                 # fct_match_participants, dim_* (gold)
│   └── Dockerfile                 # dbt-core + dbt-bigquery + project
└── docs/                          # this design doc
```

### State & layering

- **One state file per layer**, stored in the GCS backend under a key derived from
  the layer path (e.g. `dev/ingest/terraform.tfstate`) — mirrors infrastructure-live's
  `path_relative_to_include()` convention, done explicitly per layer's `backend.tf`.
- **Cross-layer wiring** uses `terraform_remote_state` data sources: `warehouse`,
  `ingest`, and `transform` read the `iam` layer's outputs (SA emails); `ingest` and
  `transform` also read `warehouse` outputs (dataset/table IDs). No hard-coded names.
- **Apply order** (each is an independent `terraform apply`):
  `bootstrap → iam → warehouse →` **CD builds & pushes both images** `→ ingest →
transform`. Both images must exist in Artifact Registry before the layers that
  reference them apply (`ingest` → extractor image, `transform` → dbt image). WIF
  is created in `bootstrap`, so GitHub Actions can authenticate and push as soon as
  bootstrap is applied.
- `common.tfvars` is passed to each layer (`-var-file=../common.tfvars`), the
  single-file stand-in for infrastructure-live's cascading `common.yaml`.

## CI/CD (GitHub Actions → Artifact Registry)

- **Trigger:** on push to the relevant paths (`extractor/**`, `dbt/**`).
- **Auth:** **Workload Identity Federation** — GitHub Actions exchanges its OIDC
  token for short-lived GCP credentials. **No service-account JSON keys**, nothing
  secret in the repo. The WIF pool/provider and a **deployer SA** (with
  `artifactregistry.writer`) are provisioned by the `wif_github` module in
  `bootstrap`. The provider is scoped to this repo (attribute condition on
  `assertion.repository`).
- **Build:** `docker build` each image and push to
  `<region>-docker.pkg.dev/<project>/<repo>/<image>:<git-sha>` (plus a `latest`
  tag). Tagging by git SHA gives immutable, roll-back-able images.
- **Deploy boundary:** CD only **builds and pushes images**. Provisioning/deploy
  of the Cloud Run Jobs is Terraform's job (`ingest`/`transform` reference the
  image URI). This keeps a clean split: CD = artifacts, Terraform = infrastructure.

## IAM (least privilege)

- `sa-extractor` (extractor Cloud Run Job **runtime** identity): `pubsub.publisher`
  on the topic, `secretmanager.secretAccessor` on the Riot key. Nothing else.
- `sa-dbt` (dbt Cloud Run Job **runtime** identity): `bigquery.dataEditor` +
  `bigquery.jobUser` scoped to the datasets it builds. **No secret access** (models
  baked into image; BQ auth via this SA's ADC).
- `sa-scheduler` (Cloud Scheduler identity that **triggers** both jobs):
  `run.jobs.run` on each job (extractor + dbt). Cloud Run **Jobs** need
  `run.jobs.run` — `run.invoker` (Services only) is not sufficient.
- `sa-pubsub-bq`: `bigquery.dataEditor` on the `bronze` dataset only (used by the
  BQ subscription). Pub/Sub's own service agent also needs this granted, plus
  `pubsub.publisher` on the dead-letter topic for dead-lettering to work.
- `sa-gh-deployer` (GitHub Actions via WIF): `artifactregistry.writer` only.
- No use of the default compute SA; no project-level `editor`; no SA JSON keys.

## Cost Controls

- **Budget alerts** at $50 / $100 / $200 (email). Alerts only — do not auto-stop.
- BigQuery **on-demand** pricing; gold **require partition filter**; `bronze`
  table **30-day expiration**.
- Cloud Run **scales to zero** between bursts (both jobs); Scheduler + Pub/Sub
  costs are negligible. GitHub Actions minutes are free for this volume.
- Nothing always-on (no Dataflow, no Composer).
- **Realistic burn: a few dollars total** at this volume.
- **Free-trial safety net:** trial accounts do not auto-charge past the $300 /
  90-day credit — resources pause when it's exhausted. Budget alerts are a
  secondary, earlier signal.
- **Permission caveat:** `google_billing_budget` requires `billing.budgets.editor`
  on the _billing account_ (not the project), which can be restricted. If
  unavailable, set the budget manually in the console and skip `budget.tf`.

## Known Constraints & Risks

- **Riot dev API key** expires every 24h and is rate-limited (~20 req/s,
  100 req/2min). Stored in Secret Manager and refreshed manually, or replaced
  with a longer-lived "personal" key via Riot's developer portal. The pipeline
  tolerates a stale/invalid key gracefully (logs + DLQ, no crash).
- **At-least-once delivery.** Pub/Sub may deliver a match more than once →
  duplicates are expected and made harmless by the idempotent dbt incremental
  `MERGE` on `(match_id, participant_id)`.
- **Terraform remote state bucket** must exist before the other layers can
  `terraform init` against it. Handled by the `envs/dev/bootstrap/` layer, which
  uses local state for itself (chicken-and-egg) and creates the GCS state bucket,
  enables service APIs, sets budget alerts, and provisions WIF + the Artifact
  Registry repo.
- **Images before apply.** Both container images must be built and pushed (by CD)
  to Artifact Registry before the layers that reference them apply (`ingest` →
  extractor, `transform` → dbt).
- **Match deduplication** depends on the `seen_matches` lookup plus the
  idempotent `MERGE`; both layers exist so a re-run never produces duplicates.
- **Dead-letter topic has no consumer.** Failed messages accrue on the DLQ and are
  inspected manually (sufficient for a study project). The DLQ subscription's
  retention bounds growth.

## Manual / out-of-band steps

These are intentionally _not_ Terraform-managed:

1. **Riot API key value** — created empty by Terraform in Secret Manager; the key
   value is added by hand (and refreshed ~daily for a dev key).
2. **GitHub repo CD config** — set the repo variables/secrets GitHub Actions needs
   to authenticate: the WIF provider resource name and the deployer SA email
   (both output by the `bootstrap` layer), plus project/region. No JSON key — WIF
   is keyless.
3. **Looker Studio report** — built in the console (no Terraform provider exists).

(Image builds are now automated by CD and are no longer a manual step.)

## Testing & Data Quality

- **dbt tests** (exam-relevant data-quality coverage): `unique` + `not_null` on
  the fact table's key columns (`match_id`, `participant_id`) and the partition
  column, `relationships` from fact → dims, and a freshness/recency test
  (`dbt_utils.recency` or `dbt source freshness`). `dbt build` runs models and
  tests together; a failing test fails the run, surfacing bad data early.
- **dbt artifacts**: optionally publish `dbt docs` / `manifest.json` from CD for
  lineage (nice-to-have).
- **Terraform**: `terraform fmt -check`, `validate`, and `plan` per layer — wired
  into a pre-commit hook (lightweight stand-in for the company's CI/Atlantis).
- **Extractor**: a `--dry-run` mode that resolves PUUIDs and logs what _would_ be
  published without calling Pub/Sub, plus unit tests for the JSON-shaping logic.
- **CD**: image build is itself a check — a broken Dockerfile or failing
  `dbt parse`/`dbt compile` step fails the workflow before a bad image ships.

## Success Criteria

1. Running the layers in order (`bootstrap → iam → warehouse → CD builds images →
ingest → transform`) provisions the full pipeline from scratch.
2. A push to `extractor/**` or `dbt/**` builds and pushes a new image to Artifact
   Registry via GitHub Actions (keyless WIF), with no JSON keys anywhere.
3. A scheduled run extracts real Riot match data and lands it in `bronze.matches_bronze`.
4. dbt builds partitioned/clustered gold via incremental MERGE with no dupes, and
   its tests pass.
5. A Looker Studio dashboard (with a `game_date` control) renders metrics from the
   gold.
6. Total spend stays well within the $300 trial.

## Future / Optional Modules

- Add a Dataflow batch Flex Template variant as a study module for the
  streaming/Beam portion of the exam.
- Add a Cloud Workflows step to orchestrate extractor → dbt run as one DAG
  (replacing the two independent Scheduler clocks).
- Add a **Dataform** variant of the transform layer as a GCP-native comparison to
  the dbt approach.
