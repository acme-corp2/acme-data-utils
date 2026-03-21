# Acme Corp — CloudSmith Migration
## Presentation Deck

**Duration**: 40 minutes (10 min walkthrough + 10 min demo + 20 min Q&A)

---

## Slide 1: Title

# Acme Corp CloudSmith Migration
### Modernizing CI/CD and Package Management

**From**: GitLab CI + JFrog Artifactory
**To**: GitHub Actions + CloudSmith

---

## Slide 2: The Challenge

### What Acme Corp Needed

| Requirement | Delivered |
|---|---|
| Migrate pipeline to GitHub Actions | ✅ |
| Migrate registry to CloudSmith | ✅ |
| Keep QA → Production promotion flow | ✅ |
| Keep manual approval gate | ✅ |
| Improve security posture | ✅ OIDC (keyless auth) |
| Add observability | ✅ Slack notifications |
| Infrastructure as Code | ✅ Terraform |

### The Four Deliverables
1. Working GitHub Actions Pipeline
2. Terraform Infrastructure Configuration
3. Comprehensive Migration Guide
4. This Presentation + Live Demo

---

## Slide 3: Architecture — Before and After

### Before: GitLab CI + JFrog Artifactory

```
Developer
   │ push
   ▼
GitLab CI ──(long-lived API key)──► JFrog Artifactory
   │                                    ├── acme-pypi-qa
   │ Manual approval (UI)               └── acme-pypi-prod
   │
   └── JFrog CLI copy: QA → Prod
```

**Problems:**
- Long-lived API keys — rotate manually, risk if leaked
- No Slack notifications
- Infrastructure set up by clicking in UI
- No vulnerability scanning on packages

---

### After: GitHub Actions + CloudSmith

```
Developer
   │ push to main (or git tag)
   ▼
GitHub Actions ──(OIDC, no stored secrets)──► CloudSmith
   │                                              ├── acme-pypi-qa (QA)
   │                                              └── acme-pypi-prod (Prod)
   │                                                    │
   │ GitHub Environment gate                            └── Webhooks → Slack
   │ (Required reviewers)
   │
   └── cloudsmith move: QA → Prod
              + Slack notification
```

**Improvements:**
- OIDC keyless auth — no secrets anywhere
- Slack notifications (pipeline events + CloudSmith webhooks)
- All infrastructure in Terraform — one command to recreate
- Built-in vulnerability scanning in CloudSmith

---

## Slide 4: Security Deep Dive — OIDC

### Before: Long-Lived API Key

```
GitLab CI variable: CLOUDSMITH_API_KEY = "cs.fKe7..."
   ↑ Stored forever
   ↑ Valid until manually rotated
   ↑ If leaked: attacker can push packages indefinitely
```

### After: OIDC (Keyless)

```
Each pipeline run:
  1. GitHub generates short-lived JWT (signed by GitHub)
  2. JWT contains claims: { repository: "acme-corp2/acme-data-utils", ref: "refs/heads/main" }
  3. CloudSmith validates signature + checks claims match config
  4. CloudSmith issues ~90 min API token
  5. Pipeline uses token → token auto-expires
  No secret is ever stored anywhere
```

### Comparison Table

| | API Key | OIDC |
|---|---|---|
| Storage | GitLab CI variable | Not stored |
| Lifetime | Until rotated | 90 minutes |
| If leaked | Valid forever | Expires in 90 min |
| Rotation | Manual | Automatic |
| Scope | Broad | Locked to repo + branch |
| Audit trail | Limited | Full GitHub Actions logs |

**OIDC provider fully managed by Terraform — zero manual UI steps needed.**

---

## Slide 5: Pipeline Walkthrough

### Four Jobs, End-to-End

```
[build]
  Checkout → Resolve version → python -m build → Upload dist/
      ↓
[test]
  Download dist/ → pip install wheel → pytest → Upload results
      ↓
[publish-qa]  (main branch / tag pushes only)
  OIDC auth → cloudsmith push → Slack: "✅ Published to QA"
      ↓
  ┌─────────────────────────────────────┐
  │   GitHub Environment: production    │
  │   Manual approval required          │
  │   → Reviewer clicks Approve         │
  └─────────────────────────────────────┘
      ↓
[promote-prod]
  OIDC auth → cloudsmith list (get slug_perm) → cloudsmith move → Slack: "🚀 Promoted to Prod"
```

### Versioning

| Trigger | Version |
|---|---|
| Push to main (1st commit after 0.1.0) | `0.1.1` |
| Push to main (2nd commit) | `0.1.2` |
| `git tag v1.2.3` | `1.2.3` |

Patch = total git commit count (`git rev-list --count HEAD`) — starts at 1, +1 per commit.
To bump major/minor: update `setup.cfg`. For a tagged release: `git tag v0.2.0 && git push origin v0.2.0`

### Package Promotion Detail

```bash
# 1. Find the package unique ID in QA
cloudsmith list packages acme-4ngc/acme-pypi-qa \
  -q "name:acme-data-utils version:1.2.3" -F pretty_json
# → parses response['data'][*]['slug_perm'] → ["abc123", "def456"]

# 2. Move each file (not copy — removes from QA, adds to prod)
cloudsmith move acme-4ngc/acme-pypi-qa/abc123 acme-pypi-prod --yes
cloudsmith move acme-4ngc/acme-pypi-qa/def456 acme-pypi-prod --yes
```

Why `move` not copy? QA is staging, not permanent. Move keeps prod as single source of truth.

---

## Slide 6: Infrastructure as Code with Terraform

### What Terraform Creates

```hcl
cloudsmith_repository "qa"           → acme-pypi-qa
cloudsmith_repository "prod"         → acme-pypi-prod
cloudsmith_service "github_actions"  → github-actions-service-4aah (slug auto-generated)
cloudsmith_repository_privileges     → service account gets Write on both repos
cloudsmith_oidc "github_actions"     → OIDC provider config (claims + service link)
cloudsmith_entitlement (x2)          → read-only tokens for developers (QA + Prod)
cloudsmith_webhook "qa"              → Slack webhook on QA events
cloudsmith_webhook "prod"            → Slack webhook on Prod events
```

### Key Point: Service Slug

CloudSmith automatically appends a random suffix to service account names:
- You input: `"github-actions-service"`
- Actual slug: `"github-actions-service-4aah"` (read from `terraform output`)

Always copy the exact slug from `terraform output github_actions_workflow_config` into the workflow.

### Benefits of IaC

- Version controlled — all changes tracked in Git
- Repeatable — `terraform apply` recreates everything from scratch
- Auditable — infrastructure changes go through PR review
- No manual UI clicking — prevents configuration drift

---

## Slide 7: Observability — Two Slack Layers

### Layer 1: GitHub Actions Slack Steps
Triggered when pipeline jobs complete. Contains CI context.

```
publish-qa completes  →  "✅ Package Published to QA — Awaiting Approval"
promote-prod completes →  "🚀 Package Promoted to Production"
Both include: version, repo link, workflow run link
```

### Layer 2: CloudSmith Native Webhooks (via Terraform)
Triggered by CloudSmith package events. Contains registry context.

```
QA events:   package.created, package.synced, package.security_scanned
Prod events: package.created, package.synced
```

### Why Two Layers?
- Layer 1 tells you: pipeline completed, who triggered it, link to run
- Layer 2 tells you: package is synced and ready, security scan result

---

## Slide 8: Developer Experience

### Installing Packages

**Before (Artifactory):**
```bash
pip install acme-data-utils \
  --index-url https://acme.jfrog.io/api/pypi/acme-pypi-prod/simple
```

**After (CloudSmith):**
```bash
pip install acme-data-utils \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
```

Entitlement token for auth is generated by Terraform and available via `terraform output`.

### What Improves for Developers

| | Before | After |
|---|---|---|
| Vulnerability info | None | Built into CloudSmith UI |
| License compliance | Manual | Automatic |
| Download speed | Self-hosted | CDN-backed |
| Install instructions | Ask DevOps | Copy-paste from CloudSmith UI |
| Package search | JFrog UI | Modern CloudSmith UI |

### What Stays the Same

- Package API — no code changes in apps that use the library
- Python package structure
- Test approach (pytest)
- Repository names (acme-pypi-qa, acme-pypi-prod)
- Version numbering (for tagged releases)

---

## Slide 9: Live Demo Plan

### What We'll Show (10 minutes)

**Part 1 — Terraform (2 min)**
- `terraform show` — live infrastructure state
- `terraform output` — repo URLs, service slug, install instructions

**Part 2 — GitHub Actions (3 min)**
- Trigger a push to main
- Watch build → test → publish-qa run
- Show OIDC authentication step (no secrets visible)
- Show package appear in CloudSmith QA

**Part 3 — Manual Approval Gate (1 min)**
- Go to GitHub Actions → Review deployments
- Click "Approve and deploy"

**Part 4 — Production Promotion (2 min)**
- Watch promote-prod job run
- Show `cloudsmith move` output (slug_perm lookup → move)
- Show package in CloudSmith Production repo
- Show QA repo — package is gone (moved, not copied)

**Part 5 — Notifications (1 min)**
- Show Slack channel — both Layer 1 and Layer 2 messages
- Show GitHub Step Summary with package details

**Part 6 — Developer Install (1 min)**
- `pip install acme-data-utils` from CloudSmith prod

### Backup Plan
If live demo fails: screenshots of each step, walk through the workflow YAML directly.

---

## Slide 10: Key Decisions

### 1. `cloudsmith move` not copy
- Package removed from QA → Production is single source of truth
- QA is a staging area, not permanent storage

### 2. OIDC not API keys
- No secret stored anywhere — strongest security posture
- Fully automated via Terraform `cloudsmith_oidc` resource

### 3. Single workflow file
- Easier to understand the full flow end-to-end
- Refactor to reusable workflows later if needed

### 4. Terraform for everything
- Including OIDC provider — zero manual steps after `terraform apply`
- Makes onboarding repeatable

### 5. Public repo
- Required for GitHub Environment protection rules on the free plan
- Enables the manual approval gate without GitHub Teams subscription

---

## Slide 11: Trade-off Handling

| Decision | Benefit | Cost |
|---|---|---|
| OIDC | No stored secrets | Repo must be public (free plan) |
| `cloudsmith move` | Clean QA, clear ownership | Package must be in QA first |
| Terraform | Fully reproducible | Learning curve |
| Single workflow | Simple | Jobs can't run independently |
| Dev versioning | No duplicate errors | Dev builds not semver-compliant |

**All trade-offs favour long-term security and maintainability over short-term convenience.**

---

## Slide 12: What's Not In Scope (And Why)

| Feature | Decision |
|---|---|
| GitHub Release | Removed — not in challenge brief; org permissions are read-only |
| Rollback workflow | Not required — manual gate prevents bad pushes; manual `cloudsmith move` available |
| Multi-package support | Out of scope — same pattern extends naturally with matrix builds |
| Notification for failed builds | Out of scope — GitHub Actions failure emails cover this |

---

## Slide 13: Rollout Plan

| Week | Action |
|---|---|
| Week 1 | Run `terraform apply`, test pipeline end-to-end, verify OIDC |
| Week 2 | Team training on new workflow + installation method |
| Week 2–3 | Parallel operation — both Artifactory and CloudSmith running |
| Week 4 | Cutover — CloudSmith becomes primary, Artifactory read-only |
| Week 12 | Decommission Artifactory |

**Rollback during transition**: JFrog Artifactory stays operational until week 12. Can revert with zero downtime.

---

## Slide 14: Q&A

### Likely Questions

**"Why CloudSmith?"**
Modern platform: built-in OIDC support, Terraform provider, vulnerability scanning, CDN delivery, better UX than self-hosted JFrog.

**"How does OIDC work exactly?"**
GitHub signs a JWT per run with claims about repo + branch. CloudSmith validates signature + checks claims. Issues a 90-min token. Secret is never stored.

**"Can you roll back a bad production release?"**
Yes manually — `cloudsmith move` is bidirectional, or delete + re-push. Primary defence is the manual approval gate before prod.

**"What if CloudSmith goes down?"**
99.9% SLA + CDN redundancy. Developers can pin package versions locally. JFrog Artifactory stays as fallback during transition period.

**"How do you handle multiple teams?"**
CloudSmith RBAC + entitlement tokens per team. Each team gets a scoped token for their repos.

**"What about the OIDC setup — is it manual?"**
No — `cloudsmith_oidc` Terraform resource handles it completely. `terraform apply` = done.

---

## Slide 15: Thank You

### Deliverables Submitted

- `.github/workflows/publish-package.yml` — Working pipeline
- `terraform/` — Full infrastructure as code
- `MIGRATION_GUIDE.md` — Developer migration guide
- `PRESENTATION.md` + live demo — This presentation

### Repository
`acme-corp2/acme-data-utils`

---

## Presentation Notes

**Timing:**
- Slides 1–3: Context + Architecture (3 min)
- Slides 4–7: Technical deep dive (4 min)
- Slides 8–9: Dev experience + demo preview (2 min)
- Slides 10–13: Decisions + rollout (1 min)
- Live demo: 10 min
- Q&A: 20 min

**Key messages to land:**
1. OIDC eliminates the biggest security risk (long-lived credentials)
2. Terraform means zero manual steps — fully reproducible
3. `cloudsmith move` keeps QA clean — proper staging semantics
4. Slack notifications = observability at two layers (pipeline + registry)
