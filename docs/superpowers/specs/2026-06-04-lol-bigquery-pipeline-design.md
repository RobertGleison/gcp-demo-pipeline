# League of Legends → BigQuery Pipeline — Design Spec

**Date:** 2026-06-04
**Status:** Approved design (implementation not yet started)
**Author:** Robert Pereira

## Purpose

Build a fully Terraform-provisioned GCP data pipeline that extracts League of
Legends match data from the Riot Games API, ingests it through Pub/Sub, lands it
in BigQuery, transforms JSON into a columnar star schema via ELT, and serves a
Looker Studio dashboard.

The project's primary goal is **hands-on practice for the GCP Professional Data
Engineer certification**, using a $300 free-trial account. Architectural choices
favor exam-relevant services and tight cost control over production realism.

## Goals

- Exercise the canonical DE stack: Pub/Sub, BigQuery, ELT/Dataform, scheduling,
  IAM, partitioning/clustering, Infrastructure as Code.
- Stay comfortably inside the $300 trial (target: a few dollars total).
- End-to-end reproducibility via Terraform.

## Non-Goals

- Production-grade reliability or real-time SLAs.
- Always-on streaming (explicitly excluded for cost — see below).
- Comprehensive coverage of every Riot API endpoint.

## Run Mode

**Scheduled batch bursts.** Cloud Scheduler triggers ingestion on a cron
interval (default every 30 min). Compute scales to zero between runs. No
always-on workers.

## Architecture

```
Cloud Scheduler ──(every 30 min)──▶ Cloud Run Job (Python extractor)
                                          │  reads seed players, calls Riot API
                                          │  publishes 1 msg per match (JSON)
                                          ▼
                                   Pub/Sub topic  ──▶ Dead-letter topic
                                          │  (BigQuery subscription, no code)
                                          ▼
                                   BigQuery  raw.matches_raw  (JSON payload + publish_time)
                                          │  Dataform (scheduled SQL, MERGE)
                                          ▼
                          staging.*  ──▶  marts.fct_match_participants (+ dims)
                                          │   partitioned + clustered
                                          ▼
                                   Looker Studio dashboard (free)
```

### Components

| Layer | Service | Rationale |
|---|---|---|
| Trigger | Cloud Scheduler | Cron-driven bursts, ~free. DE-exam orchestration topic. |
| Extract | Cloud Run Job (Python) | Calls Riot API, publishes to Pub/Sub. Scales to zero. |
| Secrets | Secret Manager | Holds the Riot API key. |
| Ingest | Pub/Sub (topic + DLQ) | Mandatory; decouples extract from load. |
| Land | Pub/Sub → BigQuery subscription | Writes raw JSON straight to BQ, no code/Dataflow. |
| Transform | Dataform (ELT in BigQuery) | JSON → typed star schema, incremental MERGE. |
| Warehouse | BigQuery | Mandatory; partitioned + clustered marts. |
| Serve | Looker Studio | Free dashboards on the marts. |
| IaC | Terraform (+ GCS remote state) | Provisions everything, least-privilege IAM, budget alert. |

### Deliberately excluded

- **Dataflow** — burns budget even in bursts; ELT in BigQuery was chosen instead.
  May be added later as an optional study module.
- **Cloud Composer / Airflow** — ~$300+/mo always-on would consume the whole
  trial. Cloud Scheduler covers orchestration cheaply.

## Data Flow

### Extractor (Cloud Run Job, each schedule tick)

1. Read a small **seed list** of players (PUUIDs / riot-ids) from config —
   e.g. 5–20 tracked accounts. Default region: `americas` routing / `na1`
   platform (configurable).
2. For each player: call `match-v5` for recent match IDs (last N, e.g. 10).
3. Skip match IDs already seen (lookup against a small `seen_matches` table or
   the marts) to limit API calls and duplicates.
4. For each new match: fetch full match JSON, publish one Pub/Sub message with
   the raw JSON body + attributes (`match_id`, `platform`, `queue_id`).
5. Respect Riot rate limits (token-bucket / sleep). On Riot 4xx/5xx: log and
   continue — never crash the whole run.

### Landing — `raw.matches_raw`

Written by the Pub/Sub BigQuery subscription using the standard schema:
`subscription_name`, `message_id`, `publish_time`, `attributes` (JSON),
`data` (JSON string = full match). Partitioned by ingest date; 30-day
expiration (raw is disposable).

### Transform — Dataform medallion model

- **staging.stg_matches** — parse `data` with `JSON_VALUE` / `JSON_QUERY`: one
  row per match (`match_id`, `game_start`, `game_duration`, `queue_id`, `patch`,
  `winning_team`).
- **staging.stg_participants** — `UNNEST` the 10 participants: one row per
  (match, player) with champion, role, K/D/A, gold, damage, win flag, etc.
- **marts.dim_champion**, **marts.dim_player** — small dimension tables.
- **marts.fct_match_participants** — fact table, **partitioned by `game_date`**,
  **clustered by `champion_id, queue_id`**. Built **incrementally** with `MERGE`
  keyed on `(match_id, participant_id)` → idempotent, re-run safe, no dupes.

### Serving — Looker Studio

Dashboards on the marts: win rate by champion, KDA distributions, gold/damage
curves, game-duration trends, per-player scorecards.

## Repository Layout

The IaC structure is **plain Terraform organized in the spirit of the company's
`infrastructure-live` (Terragrunt) repo**: reusable `modules/` separated from
per-environment "live" config, and **each pipeline layer owns its own state file**
for blast-radius isolation. Terragrunt itself was considered but rejected — with a
single env/region/project its DRY machinery is overhead, and plain Terraform keeps
the workflow closest to a vanilla Data Engineer exam toolchain.

```
gcp-demo-pipeline/
├── modules/                       # reusable building blocks (no state of their own)
│   ├── service_account/           # SA + scoped role bindings
│   ├── pubsub_bq/                 # topic + DLQ + BigQuery subscription
│   ├── bigquery_datasets/         # raw / staging / marts datasets, partition/cluster
│   ├── cloudrun_extractor/        # Cloud Run Job + Scheduler + Secret Manager
│   └── dataform/                  # Dataform repo + release/workflow config
├── envs/
│   └── dev/                       # the only environment (one GCP project)
│       ├── common.tfvars          # project_id, region, dataset names, schedule, seed players
│       ├── bootstrap/             # one-time: GCS state bucket, enable APIs, budget alerts
│       ├── iam/                   # service accounts → outputs SA emails
│       ├── warehouse/             # BigQuery datasets (reads iam state)
│       ├── ingest/                # Pub/Sub + BQ subscription + extractor (reads iam + warehouse)
│       └── transform/             # Dataform (reads iam + warehouse)
├── extractor/                     # Python Cloud Run Job source + Dockerfile
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── dataform/                      # SQLX models (staging + marts)
│   └── definitions/
└── docs/superpowers/specs/        # this design doc
```

### State & layering

- **One state file per layer**, stored in the GCS backend under a key derived from
  the layer path (e.g. `dev/ingest/terraform.tfstate`) — mirrors infrastructure-live's
  `path_relative_to_include()` convention, done explicitly per layer's `backend.tf`.
- **Cross-layer wiring** uses `terraform_remote_state` data sources: `warehouse`,
  `ingest`, and `transform` read the `iam` layer's outputs (SA emails); `ingest` and
  `transform` also read `warehouse` outputs (dataset/table IDs). No hard-coded names.
- **Apply order** (each is an independent `terraform apply`):
  `bootstrap → iam → warehouse → ingest → transform`. Looker Studio is wired manually.
- `common.tfvars` is passed to each layer (`-var-file=../common.tfvars`), the
  single-file stand-in for infrastructure-live's cascading `common.yaml`.

## IAM (least privilege)

- `sa-extractor`: `pubsub.publisher` on the topic, `secretmanager.secretAccessor`
  on the key, `run.invoker`. Nothing else.
- `sa-pubsub-bq`: `bigquery.dataEditor` on the `raw` dataset only (used by the
  BQ subscription).
- `sa-dataform`: `bigquery.dataEditor` + `bigquery.jobUser` scoped to the
  datasets it builds.
- No use of the default compute SA; no project-level `editor`.

## Cost Controls

- **Budget alerts** at $50 / $100 / $200 (email). Alerts only — do not auto-stop.
- BigQuery **on-demand** pricing; marts **require partition filter**; `raw`
  table **30-day expiration**.
- Cloud Run **scales to zero** between bursts; Scheduler + Pub/Sub costs are
  negligible.
- Nothing always-on (no Dataflow, no Composer).
- **Realistic burn: a few dollars total** at this volume.

## Known Constraints & Risks

- **Riot dev API key** expires every 24h and is rate-limited (~20 req/s,
  100 req/2min). Stored in Secret Manager and refreshed manually, or replaced
  with a longer-lived "personal" key via Riot's developer portal. The pipeline
  tolerates a stale/invalid key gracefully (logs + DLQ, no crash).
- **Terraform remote state bucket** must exist before the other layers can
  `terraform init` against it. Handled by the `envs/dev/bootstrap/` layer, which
  uses local state for itself (chicken-and-egg) and creates the GCS state bucket,
  enables service APIs, and sets the budget alerts.
- **Match deduplication** depends on the `seen_matches` lookup plus the
  idempotent `MERGE`; both layers exist so a re-run never produces duplicates.

## Success Criteria

1. `terraform apply` provisions the full pipeline from scratch.
2. A scheduled run extracts real Riot match data and lands it in `raw.matches_raw`.
3. Dataform builds partitioned/clustered marts via incremental MERGE with no dupes.
4. A Looker Studio dashboard renders metrics from the marts.
5. Total spend stays well within the $300 trial.

## Future / Optional Modules

- Add a Dataflow batch Flex Template variant as a study module for the
  streaming/Beam portion of the exam.
- Add a Cloud Workflows step to orchestrate extractor → Dataform run as one DAG.
