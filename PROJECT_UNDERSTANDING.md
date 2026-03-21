# CloudSmith Integration Challenge — Complete Reference
> Personal understanding document. Not for submission. Last updated: 2026-03-21.

---

## 1. Challenge Overview

**Client**: Acme Corp — mid-size data analytics company
**Task**: Migrate CI/CD pipeline and package registry
**From**: GitLab CI + JFrog Artifactory (self-hosted)
**To**: GitHub Actions + CloudSmith

**Four required deliverables:**
1. Working GitHub Actions Pipeline (`.github/workflows/publish-package.yml`)
2. Terraform Infrastructure (`terraform/`)
3. Migration Guide (`MIGRATION_GUIDE.md`)
4. Presentation Deck (`PRESENTATION.md`) + live demo

**Presentation format**: 40 min total — 10 min walkthrough + 10 min demo + 20 min Q&A

---

## 2. What Was There Before (AS-IS)

| Area | Old Stack |
|------|-----------|
| CI/CD | GitLab CI (self-hosted runners) |
| Package registry | JFrog Artifactory (on-premises) |
| Auth | Long-lived API keys stored in GitLab CI variables |
| Infrastructure | Manually configured via UI |
| Package | `acme-data-utils` Python library v0.1.0 |
| Build tool | `python -m build` → twine push |
| QA repo | `acme-pypi-qa` |
| Prod repo | `acme-pypi-prod` |
| Promotion | JFrog CLI copy (QA → Prod) |
| Notifications | None |

**Pain points:**
- Long-lived API keys (security risk, manual rotation)
- No observability (no Slack notifications, no job summaries)
- Infrastructure managed via clicking in UI (not repeatable)
- No built-in vulnerability scanning

---

## 3. What We Built (TO-BE)

| Area | New Stack |
|------|-----------|
| CI/CD | GitHub Actions |
| Package registry | CloudSmith |
| Auth | OIDC (keyless — no stored secrets) |
| Infrastructure | Terraform (`cloudsmith` provider) |
| Promotion | `cloudsmith move` (QA → Prod, removes from QA) |
| Notifications | Slack (2 layers: GitHub Actions step + CloudSmith native webhooks) |
| Versioning | `0.1.0.devN` per push, `X.Y.Z` on git tag |

---

## 4. One-Time Setup Order (What to Do First)

```
Step 1 — Fill in terraform/terraform.tfvars
         cloudsmith_namespace = "acme-4ngc"
         cloudsmith_api_key   = "<from CloudSmith UI → User Settings → API Keys>"
         admin_user_slug      = "kapil-sharma"
         github_repository    = "acme-corp2/acme-data-utils"
         github_ref           = "refs/heads/main"
         webhook_url          = "<Slack Incoming Webhook URL>"

Step 2 — cd terraform && terraform init && terraform apply
         Creates all CloudSmith resources (see Section 8 for full list)

Step 3 — Copy values from terraform output into workflow
         terraform output github_actions_workflow_config
         oidc_namespace    → CLOUDSMITH_NAMESPACE in workflow env  (e.g. "acme-4ngc")
         oidc_service_slug → oidc-service-slug in workflow         (e.g. "github-actions-service-4aah")
         NOTE: CloudSmith auto-appends a random suffix to service account name.
               Always use the value from terraform output, not the name you typed.

Step 4 — Configure GitHub Environment
         Settings → Environments → New environment → name: "production"
         Add required reviewers (yourself or team)
         NOTE: Repo must be public for this to work on the GitHub free plan.

Step 5 — Add GitHub Secret
         Settings → Secrets and variables → Actions → New repository secret
         Name: SLACK_WEBHOOK_URL
         Value: <same Slack webhook URL as terraform.tfvars>
```

---

## 5. Where Every Variable Comes From

| Variable | Where it lives | How to get it |
|---|---|---|
| `CLOUDSMITH_NAMESPACE` | Workflow `env:` | `terraform output` → `oidc_namespace` |
| `oidc-service-slug` | Workflow auth step | `terraform output` → `oidc_service_slug` (has random suffix!) |
| `QA_REPO` | Workflow `env:` | Hardcoded `"acme-pypi-qa"` |
| `PROD_REPO` | Workflow `env:` | Hardcoded `"acme-pypi-prod"` |
| `SLACK_WEBHOOK_URL` | GitHub Secret | Slack UI → create Incoming Webhook → copy URL |
| `cloudsmith_api_key` | `terraform.tfvars` (local, never committed) | CloudSmith UI → User Settings → API Keys |
| `admin_user_slug` | `terraform.tfvars` | Your CloudSmith username (lowercase, hyphens) |
| `github_repository` | `terraform.tfvars` | `"acme-corp2/acme-data-utils"` |
| `webhook_url` | `terraform.tfvars` | Slack Incoming Webhook URL |

---

## 6. OIDC Authentication Flow (Keyless Auth — How It Works)

```
GitHub Actions Runner
│
├─ 1. Workflow step: cloudsmith-io/cloudsmith-cli-action@v2
│      with oidc-namespace: "acme-4ngc"
│           oidc-service-slug: "github-actions-service-4aah"
│
├─ 2. Action requests OIDC token from GitHub's token endpoint
│      (requires permission: id-token: write in workflow)
│      Token contains claims:
│        repository: "acme-corp2/acme-data-utils"
│        ref: "refs/heads/main"
│        (plus actor, run_id, etc.)
│
├─ 3. Action sends token to CloudSmith OIDC endpoint
│      POST https://api.cloudsmith.io/v1/oidc/acme-4ngc/
│
├─ 4. CloudSmith validates token
│        Verifies GitHub's signature ✓
│        Checks claims match cloudsmith_oidc Terraform config:
│          repository == "acme-corp2/acme-data-utils" ✓
│          ref == "refs/heads/main" ✓
│        Confirms linked service account: github-actions-service-4aah ✓
│
├─ 5. CloudSmith issues short-lived token (~90 min)
│      Stored as env var: CLOUDSMITH_API_KEY
│
└─ 6. All `cloudsmith` CLI calls in the job use this token automatically
       Token expires on its own — nothing to clean up
```

**Security benefit over API keys:**
- Token is generated fresh per pipeline run
- Expires in 90 min regardless (cannot be leaked and reused)
- Scoped: only `acme-corp2/acme-data-utils` on `refs/heads/main` can get a token
- No secret stored anywhere in GitHub or the repo

---

## 7. CI/CD Pipeline Flow (Every Push to Main or Tag)

```
Developer pushes to main branch (or pushes a version tag like v1.2.3)
│
▼
[Job 1: build]
├─ Checkout code
├─ Setup Python 3.11
├─ Install: pip install build wheel setuptools
├─ Resolve version:
│    If tag push (v1.2.3)  → VERSION = "1.2.3"        (strips leading "v")
│    If regular push       → VERSION = "0.1.0.dev42"   (base + run_number)
│    Patches acme-data-utils/setup.cfg with this version before building
├─ cd acme-data-utils && python -m build
│    Produces: dist/acme_data_utils-<VERSION>-py3-none-any.whl
│              dist/acme_data_utils-<VERSION>.tar.gz
└─ Upload dist/ as artifact "python-package-distributions" (kept 1 day)

▼
[Job 2: test]  (needs: build)
├─ Download artifact → dist/
├─ pip install dist/*.whl pytest pytest-cov
├─ pytest tests/ --junitxml --cov
├─ Upload test-results.xml, coverage.xml as artifacts
└─ Publish test results as GitHub check run

▼  (only runs if push to main OR tag push — skipped on PRs)
[Job 3: publish-qa]
├─ Download artifact → dist/
├─ OIDC auth via cloudsmith-cli-action@v2
├─ cloudsmith push python acme-4ngc/acme-pypi-qa dist/*.whl --republish
├─ cloudsmith push python acme-4ngc/acme-pypi-qa dist/*.tar.gz --republish
├─ Read version from wheel filename (e.g. acme_data_utils-0.1.0.dev42-py3-none-any.whl)
├─ Write GitHub Step Summary (version, repo link)
└─ Slack: "✅ Package Published to QA — Awaiting Approval"

▼  ← PIPELINE PAUSES HERE — waits for human to click Approve
[GitHub Environment: production]
   Go to: GitHub → Actions → (this run) → Review deployments → Approve and deploy

▼
[Job 4: promote-prod]  (needs: publish-qa, environment: production)
├─ Download artifact → dist/  (to read version from wheel filename)
├─ OIDC auth
├─ Read version from wheel filename
├─ cloudsmith list packages acme-4ngc/acme-pypi-qa
│    -q "name:acme-data-utils version:<VERSION>" -F pretty_json
│    Parse response['data'][*]['slug_perm']
│    e.g. ["abc123xyz", "def456uvw"]  (one slug_perm per file: .whl and .tar.gz)
├─ for each slug_perm:
│    cloudsmith move acme-4ngc/acme-pypi-qa/<slug_perm> acme-pypi-prod --yes
│    Package REMOVED from QA, ADDED to Production (clean promotion)
├─ Write GitHub Step Summary
└─ Slack: "🚀 Package Promoted to Production"
```

**Versioning rules:**

| Trigger | Version example |
|---|---|
| `git push origin main` (run #19) | `0.1.19` |
| `git push origin main` (run #20) | `0.1.20` |
| `git tag v1.2.3 && git push origin v1.2.3` | `1.2.3` |

How patch auto-increment works:
- `setup.cfg` has `version = 0.1.0`
- Pipeline reads `major.minor` = `0.1`
- Patch = `github.run_number` (always incrementing per workflow run)
- Result: `0.1.19`, `0.1.20`, `0.1.21`, ...

To bump major or minor version: update `setup.cfg` (e.g. `0.2.0`)
→ next push will produce `0.2.<run_number>`

To release a proper tagged version:
```bash
git tag v0.2.0
git push origin v0.2.0
```

---

## 8. Terraform Resources Map (What `terraform apply` Creates)

```
cloudsmith_repository "qa"
  └─ slug: acme-pypi-qa  (Private, delete allowed)

cloudsmith_repository "prod"
  └─ slug: acme-pypi-prod  (Private, delete = Admin only)

cloudsmith_service "github_actions"
  └─ name input: "github-actions-service"
     actual slug: "github-actions-service-4aah"
     ↑ CloudSmith auto-appends a random suffix — always read from terraform output

cloudsmith_repository_privileges "github_actions_qa"
  ├─ user: kapil-sharma  → Admin
  └─ service: github-actions-service-4aah → Write

cloudsmith_repository_privileges "github_actions_prod"
  ├─ user: kapil-sharma  → Admin
  └─ service: github-actions-service-4aah → Write

cloudsmith_oidc "github_actions"
  ├─ provider_url: https://token.actions.githubusercontent.com
  ├─ claims: { repository: "acme-corp2/acme-data-utils", ref: "refs/heads/main" }
  └─ service_accounts: ["github-actions-service-4aah"]

cloudsmith_entitlement "developer_readonly_qa"
  └─ read-only install token for acme-pypi-qa

cloudsmith_entitlement "developer_readonly_prod"
  └─ read-only install token for acme-pypi-prod

cloudsmith_webhook "qa_package_published"  (only if webhook_url != "" in tfvars)
  ├─ events: package.created, package.synced, package.security_scanned
  └─ target_url: Slack Incoming Webhook URL

cloudsmith_webhook "prod_package_published"  (only if webhook_url != "" in tfvars)
  ├─ events: package.created, package.synced
  └─ target_url: Slack Incoming Webhook URL
```

---

## 9. Notification Flow (Two Slack Layers)

**Layer 1 — GitHub Actions steps (pipeline-triggered):**
- `publish-qa` job ends → Slack: "✅ Package Published to QA — Awaiting Approval"
- `promote-prod` job ends → Slack: "🚀 Package Promoted to Production"
- Contains: package name, version, repo link, GitHub workflow run link

**Layer 2 — CloudSmith native webhooks (package-event-triggered):**
- QA events: `package.created`, `package.synced`, `package.security_scanned`
- Prod events: `package.created`, `package.synced`
- CloudSmith sends these directly to Slack

**Why two layers?**
- Layer 1 = CI/CD context (who triggered, run link, version number from workflow perspective)
- Layer 2 = CloudSmith context (security scan result, sync status from registry side)

---

## 10. Key Decisions and Trade-offs

| Decision | Why | Trade-off |
|---|---|---|
| `cloudsmith move` not copy | QA stays clean, clear ownership. Package removed from QA → prod is only source | Package must exist in QA first |
| OIDC not API keys | No stored secrets, auto-expiring, scoped to repo+branch | Repo must be public for free GitHub plan |
| Terraform manages everything incl. OIDC | Fully reproducible, no manual UI steps | Requires provider v0.0.69+ |
| Single workflow file | Easy to see end-to-end flow | Can't trigger jobs independently |
| `0.1.0.devN` versioning | Unique version per push → no CloudSmith "already exists" errors | dev versions not semver-compliant (fine for QA) |
| Public repo | GitHub Environment protection on free plan requires it | Source code is visible |
| No GitHub Release step | Not required by challenge brief + org permissions were read-only | No GitHub Release created |

---

## 11. Disaster Recovery / Rollback

No automated rollback in current pipeline (not required by challenge). Primary safeguard is the manual approval gate.

**Manual options if bad package reaches production:**

```bash
# Option 1: Move it back to QA
cloudsmith move acme-4ngc/acme-pypi-prod/<slug_perm> acme-pypi-qa --yes

# Option 2: Delete from prod entirely
cloudsmith delete acme-4ngc/acme-pypi-prod/<slug_perm> --yes

# Option 3: Re-promote a previous good build
# Re-run a previous workflow's promote-prod job from GitHub Actions UI
# (artifacts kept for 1 day by default — increase retention if needed)

# Option 4: Push a fixed version directly
cloudsmith push python acme-4ngc/acme-pypi-prod dist/fixed.whl
```

---

## 12. Q&A Preparation

**Q: Why CloudSmith over alternatives?**
Built-in OIDC, Terraform provider, vulnerability scanning, modern UI, CDN-backed downloads, better than self-hosting JFrog.

**Q: How does OIDC work?**
GitHub generates a short-lived signed JWT per pipeline run. CloudSmith validates claims (repo + branch). If valid → issues ~90 min API token. No secret ever stored anywhere.

**Q: Why `cloudsmith move` instead of copy?**
Move removes from QA so production is the single source of truth. QA is staging, not permanent storage. Package provenance is preserved (same artifact, different location).

**Q: Can you roll back a bad prod push?**
Yes, manually via `cloudsmith move` in reverse. The manual approval gate prevents bad builds reaching prod in the first place.

**Q: What if someone pushes from a branch other than main?**
OIDC claims require `ref: "refs/heads/main"` — token request from any other branch will fail. Pipeline stops at auth step.

**Q: What about versioning — won't dev builds clutter QA?**
Every push to main gets a unique `0.1.0.devN`. `--republish` flag means re-running the same workflow number overwrites. For a real release, push a git tag.

**Q: How do developers install the package?**
```bash
pip install acme-data-utils \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
```
Entitlement token is generated by Terraform and available via `terraform output`.

**Q: Is there a rollout plan?**
Week 1: Setup + test. Week 2: Team training + parallel operation. Week 4: Cutover. Week 12: Decommission JFrog.

---

## 13. Files That Matter

| File | Purpose | Submit? |
|---|---|---|
| `.github/workflows/publish-package.yml` | CI/CD pipeline | ✅ |
| `terraform/main.tf` | CloudSmith resources | ✅ |
| `terraform/variables.tf` | Variable declarations | ✅ |
| `terraform/outputs.tf` | Output values | ✅ |
| `terraform/terraform.tfvars.example` | Example config | ✅ |
| `MIGRATION_GUIDE.md` | Developer migration guide | ✅ |
| `PRESENTATION.md` | Slides | ✅ |
| `README.md` | Repo overview | ✅ |
| `terraform/terraform.tfvars` | Actual secrets | ❌ Never commit |
| `TERRAFORM_OUTPUTS.txt` | Saved outputs | ❌ Never commit |
| `PROJECT_UNDERSTANDING.md` | This file (personal) | ❌ |

---

## 14. Pre-Demo Checklist

- [ ] `cd terraform && terraform show` — confirm all resources exist
- [ ] `terraform output` — note service slug + repo URLs
- [ ] CloudSmith UI — both repos exist, packages visible in QA after last run
- [ ] GitHub → Settings → Environments → `production` has required reviewers set
- [ ] GitHub → Secrets → `SLACK_WEBHOOK_URL` is present
- [ ] Slack channel — can see notifications arriving
- [ ] Make one test push → verify full pipeline runs end-to-end

**Browser tabs to have open during demo:**
1. GitHub repo → Actions tab
2. CloudSmith `acme-pypi-qa` repo
3. CloudSmith `acme-pypi-prod` repo
4. Terminal with `terraform/` open
5. Slack channel for notifications
