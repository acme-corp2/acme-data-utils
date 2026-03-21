# Acme Corp — CloudSmith Integration Challenge

**Migration from GitLab CI + JFrog Artifactory → GitHub Actions + CloudSmith**

---

## Overview

Migrate `acme-data-utils` Python package pipeline while maintaining the QA-to-production promotion workflow, adding keyless OIDC authentication, Slack observability, and full infrastructure as code.

**Deliverables:**
- Working GitHub Actions pipeline (build → test → publish QA → manual gate → promote prod)
- Terraform infrastructure (repos, service account, OIDC provider, webhooks, entitlement tokens)
- Migration guide for the engineering team
- Presentation deck

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── publish-package.yml          # Main CI/CD workflow
│
├── acme-data-utils/                     # Python package
│   ├── acme_data_utils/                 # Source code
│   ├── tests/                           # Test suite
│   ├── setup.cfg                        # Package metadata and base version
│   ├── setup.py
│   └── pyproject.toml
│
├── terraform/                           # Infrastructure as Code
│   ├── main.tf                          # CloudSmith resources
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example         # Fill this in (copy to terraform.tfvars)
│   ├── .gitignore
│   └── README.md
│
├── scripts/
│   └── sync-terraform-config.sh        # Syncs terraform output → workflow file
│
├── MIGRATION_GUIDE.md                   # For the engineering team
├── PRESENTATION.md                      # Slide deck
├── challenge-brief.md                   # Original requirements
└── README.md
```

---

## Setup (One Time)

### Prerequisites

- Terraform >= 1.0
- Python >= 3.9
- CloudSmith account with an organisation created
- GitHub repository (public — required for Environment protection rules on free plan)

### Step 1: Provision Infrastructure

```bash
cd terraform/

# Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars
# Edit: cloudsmith_namespace, cloudsmith_api_key, admin_user_slug,
#       github_repository, github_ref, webhook_url (Slack)

terraform init
terraform plan
terraform apply
```

Terraform creates:
- `acme-pypi-qa` and `acme-pypi-prod` repositories
- Service account for GitHub Actions OIDC
- OIDC provider (no manual CloudSmith UI steps required)
- Repository privileges for the service account
- Developer read-only entitlement tokens (QA + prod)
- Slack webhooks for package events (QA + prod)

### Step 2: Sync Terraform Outputs into the Workflow

CloudSmith auto-appends a random suffix to the service account slug (e.g. `github-actions-service-4aah`). Run the sync script so you never have to copy it manually:

```bash
cd ..
bash scripts/sync-terraform-config.sh
```

This reads `terraform output` and updates `CLOUDSMITH_NAMESPACE` and all three `oidc-service-slug` occurrences in the workflow file. Re-run it any time you do `terraform apply` again.

### Step 3: Add GitHub Secret

```
Settings → Secrets and variables → Actions → New repository secret
Name:  SLACK_WEBHOOK_URL
Value: <your Slack Incoming Webhook URL>
```

### Step 4: Configure GitHub Environment

```
Settings → Environments → New environment → name: production
Add required reviewers (yourself or your team)
```

### Step 5: Push and Test

```bash
git add .github/workflows/publish-package.yml
git commit -m "chore: sync workflow config from terraform output"
git push origin main
```

Watch the pipeline run at: `https://github.com/<org>/<repo>/actions`

---

## Pipeline Flow

```
Push to main  (or git tag v1.2.3)
      │
      ▼
[build]
  OIDC auth → query CloudSmith prod for latest version → increment patch by 1
  python -m build → upload dist/ artifact

      ▼
[test]
  pytest with coverage → publish test results as GitHub check

      ▼
[publish-qa]  (main / tag only — skipped on PRs)
  cloudsmith push → acme-pypi-qa
  Slack: "✅ Package Published to QA — Awaiting Approval"

      ▼   ← pipeline pauses here
[GitHub Environment: production]
  Required reviewer approves at:
  Actions → (this run) → Review deployments → Approve and deploy

      ▼
[promote-prod]
  cloudsmith list → get slug_perm for each file
  cloudsmith move acme-4ngc/acme-pypi-qa/<slug_perm> acme-pypi-prod --yes
  Package REMOVED from QA, ADDED to production
  Slack: "🚀 Package Promoted to Production"
```

### Versioning

| Trigger | Version |
|---|---|
| Push to main (prod has `0.1.0`) | `0.1.1` |
| Push to main (prod has `0.1.1`) | `0.1.2` |
| `git tag v1.2.3` | `1.2.3` |

Version is fetched from CloudSmith production at build time — latest prod version + 1 patch.
For a proper release: `git tag v0.2.0 && git push origin v0.2.0`

---

## OIDC Authentication

No API keys stored anywhere. Each pipeline run:

1. GitHub generates a short-lived JWT signed with GitHub's key
2. JWT contains claims: `repository` and `ref` (locked to this repo + main branch)
3. CloudSmith validates signature and claims
4. CloudSmith issues a ~90-minute scoped token
5. Token used for all `cloudsmith` CLI calls, then auto-expires

The OIDC provider is fully configured by Terraform (`cloudsmith_oidc` resource) — no manual UI steps.

---

## Observability

**Two Slack notification layers:**

| Layer | Trigger | Content |
|---|---|---|
| GitHub Actions step | Pipeline job completes | Version, repo link, workflow run link |
| CloudSmith native webhook | Package event in registry | package.created, package.synced, package.security_scanned |

---

## Key Decisions

| Decision | Reason |
|---|---|
| `cloudsmith move` not copy | Removes from QA → prod is single source of truth |
| OIDC not API keys | No stored secrets, auto-expiring, scoped to repo + branch |
| Terraform manages OIDC | Zero manual steps — fully reproducible |
| Version from prod registry | Always sequential (+1 from last prod release) |
| Public repo | Required for GitHub Environment protection on free plan |
| No GitHub Release step | Not in challenge brief; org-level permissions are read-only |

---

## Troubleshooting

**OIDC auth fails**
- Run `bash scripts/sync-terraform-config.sh` — the service slug may have changed after a re-apply
- Verify `cloudsmith_oidc` resource exists: `terraform show`

**Package not found when promoting**
- Check the package is fully synced in QA (CloudSmith takes a few seconds)
- Verify version in QA matches what the workflow resolved

**GitHub Environment approval not triggering**
- Confirm repo is public (required on free plan)
- Confirm `production` environment exists with at least one required reviewer

**Terraform apply fails**
- Verify `cloudsmith_api_key` in `terraform.tfvars` is valid
- Confirm account has Manager or Owner role in the CloudSmith organisation

---

## Resources

- CloudSmith Docs: https://docs.cloudsmith.com
- CloudSmith OIDC: https://docs.cloudsmith.com/authentication/setup-cloudsmith-to-authenticate-with-oidc-in-github-actions
- Terraform Provider: https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs
- GitHub Environments: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment
