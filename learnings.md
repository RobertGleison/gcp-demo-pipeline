# Learnings

A running log of concepts learned while building this pipeline, written for the
GCP Professional Data Engineer exam.

---

## Workload Identity Federation (WIF) — keyless CI/CD auth

### The problem

CD runs in **GitHub Actions**, which is *outside* GCP. To push Docker images to
Artifact Registry, GitHub must prove to GCP that it's allowed to. That's
authentication — the question is *how* it proves it.

### The old way: service account JSON keys (avoid)

1. Create a service account.
2. Generate a **JSON key file** — a credential that **never expires**.
3. Paste it into GitHub repo secrets.

Why it's bad (and why the spec forbids it):

- It's a **long-lived secret**. Leak it (logs, a bad dependency, a screenshot)
  and an attacker has standing GCP access until you notice and revoke.
- It doesn't expire on its own; rotation is manual and usually skipped.
- It lives in two places (GCP + GitHub) — double the leak surface.

Leaked SA keys are one of the most common ways GCP projects get breached.

### The new way: Workload Identity Federation

The insight: **GitHub already proves who it is.** Every Actions run gets a
short-lived, signed **OIDC token** asserting:

> "I'm running in repo `owner/repo`, branch `main`, commit `abc123`" — signed by
> GitHub, verifiable by GCP.

WIF tells GCP: *trust tokens signed by GitHub; when one claims it's from
`owner/repo`, mint short-lived (~1h) credentials to act as the deployer SA.*

```
GitHub Actions run
   │  GitHub issues signed OIDC token: "I'm repo owner/repo"
   ▼
GCP Workload Identity Pool / Provider
   │  verifies GitHub's signature
   │  checks attribute condition: repository == "owner/repo"  ✅
   ▼
GCP returns a ~1-hour token to act as sa-gh-deployer
   ▼
docker push → Artifact Registry   (then the token expires)
```

**No stored secret.** Nothing to leak, nothing to rotate. Trust is bound to
GitHub's signed claims, not to a copyable file.

### The four resources (`modules/wif_github/`)

| Resource | Plain English |
|---|---|
| **Workload Identity Pool** | Container for "external identities we trust." |
| **OIDC Provider** | "Trust GitHub's issuer" + the lock `repository == "owner/repo"`. |
| **Deployer SA** (`sa-gh-deployer`) | The GCP identity GitHub becomes. Only power: `artifactregistry.writer`. |
| **`workloadIdentityUser` binding** | "Actions from `owner/repo` may impersonate the deployer SA." |

The `attribute_condition` is the security boundary — without it, *any* GitHub repo
could federate. The `principalSet://.../attribute.repository/owner/repo` member on
the binding restricts impersonation to that one repo.

### Why it lives in `bootstrap`

CD pushes the images, and the images must exist in Artifact Registry **before**
the `ingest`/`transform` layers apply. So WIF — what lets CD authenticate — has to
exist in the earliest layer.

### One sentence

> WIF lets GitHub Actions push to GCP using GitHub's own short-lived identity
> token instead of a stealable, never-expiring JSON key file.

### Exam hooks

- Cloud Run **Jobs** need `run.jobs.run`, not `run.invoker` (which is Services only).
- WIF needs the `iamcredentials` and `sts` APIs enabled.
- The OIDC issuer for GitHub is `https://token.actions.githubusercontent.com`.
