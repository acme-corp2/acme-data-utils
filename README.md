# Acme Corp CloudSmith Integration Challenge

**Migration from GitLab CI + JFrog Artifactory to GitHub Actions + CloudSmith**

This repository contains a complete solution for migrating Acme Corp's CI/CD pipeline and package management infrastructure to modern, secure tooling.

---

## Overview

**Challenge**: Migrate `acme-data-utils` Python package from GitLab CI + Artifactory to GitHub Actions + CloudSmith while maintaining QA-to-production promotion workflow.

**Solution Highlights**:
- ✅ Working GitHub Actions pipeline with 4 stages (build → test → publish-qa → promote-prod)
- ✅ OIDC keyless authentication (no long-lived secrets)
- ✅ Terraform infrastructure as code (repos, service account, permissions, webhooks)
- ✅ Comprehensive migration guide
- ✅ Live demo presentation materials
- ✅ Slack notifications on QA publish and production promotion
- ✅ Improved observability and developer experience

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── publish-package.yml            # Main CI/CD workflow (OIDC)
│       └── publish-package-apikey.yml.disabled  # Fallback (API key)
│
├── acme-data-utils/                       # Python package to publish
│   ├── acme_data_utils/                   # Source code
│   ├── tests/                             # Test suite
│   ├── setup.cfg                          # Package metadata
│   ├── setup.py                           # Build configuration
│   └── pyproject.toml                     # Build system requirements
│
├── terraform/                             # Infrastructure as Code
│   ├── main.tf                            # CloudSmith resources
│   ├── variables.tf                       # Input variables
│   ├── outputs.tf                         # Output values
│   ├── terraform.tfvars.example           # Example values
│   ├── .gitignore                         # Terraform gitignore
│   └── README.md                          # Terraform setup guide
│
├── MIGRATION_GUIDE.md                     # For engineering team
├── PIPELINE_ARCHITECTURE.md               # Technical architecture
├── PROJECT_UNDERSTANDING.md               # Challenge analysis
├── PRESENTATION.md                        # Slide deck (markdown)
├── DEMO_SCRIPT.md                         # Live demo walkthrough
├── challenge-brief.md                     # Original requirements
└── README.md                              # This file
```

---

## Quick Start

### Prerequisites

1. **CloudSmith Account**
   - Sign up at https://cloudsmith.com
   - Create organization (e.g., "acme")
   - Note your organization name

2. **GitHub Repository**
   - Fork or create new repository
   - Clone locally

3. **Tools**
   - Terraform >= 1.0
   - Python >= 3.9
   - Git

### Step 1: Set Up Infrastructure

```bash
# Navigate to terraform directory
cd terraform/

# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
# Set: cloudsmith_namespace, cloudsmith_api_key, github_repository

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply configuration
terraform apply

# Save outputs
terraform output > ../TERRAFORM_OUTPUTS.txt
```

Then sync the Terraform outputs into the GitHub Actions workflow automatically:

```bash
cd ..
bash scripts/sync-terraform-config.sh
```

This updates `CLOUDSMITH_NAMESPACE` and `oidc-service-slug` in the workflow file with the exact values from your Terraform state (including the auto-generated service slug suffix).

### Step 2: OIDC Provider

**Fully managed by Terraform** — no manual UI steps needed.

The `cloudsmith_oidc` resource in `terraform/main.tf` configures the GitHub OIDC provider automatically when you run `terraform apply`. It sets:
- Provider URL: `https://token.actions.githubusercontent.com`
- Claims: `repository` and `ref` from your `terraform.tfvars`
- Service account: the one created by Terraform

### Step 3: Configure GitHub

```bash
# Create production environment
# Settings → Environments → New environment → "production"

# Add required reviewers
# Settings → Environments → production → Required reviewers → Add

# Commit workflows to repository
git add .github/workflows/
git commit -m "Add GitHub Actions workflows"
git push origin main
```

### Step 4: Test Pipeline

```bash
# Make a test change
cd acme-data-utils/
echo "# Test" >> README.md

# Commit and push to main
git add README.md
git commit -m "Test pipeline"
git push origin main

# Watch workflow run
# Go to: https://github.com/<your-org>/<your-repo>/actions
```

### Step 5: Approve and Promote

1. Wait for build, test, publish-qa stages to complete
2. Check your Slack channel for the "Package Published to QA" notification
3. Navigate to Actions → Workflow run → "Review deployments"
4. Click "Approve and deploy"
5. Watch promote-prod stage execute — package is *moved* from QA to production
6. Check Slack for the "Package Promoted to Production" notification

---

## Deliverables

### 1. GitHub Actions Workflow ✅

**File**: `.github/workflows/publish-package.yml`

**Features**:
- 4-stage pipeline (build, test, publish-qa, promote-prod) with manual approval gate via GitHub Environment
- OIDC keyless authentication (no stored secrets)
- Automatic vulnerability scanning via CloudSmith
- Slack notifications on QA publish and production promotion
- Job summaries with package links and next steps

**Key Improvements over GitLab CI**:
- No secrets to manage (OIDC)
- Better observability (Slack notifications, CloudSmith dashboard)
- Manual approval gate via GitHub Environments (required reviewers)
- QA packages *moved* (not copied) to production — clean promotion workflow

### 2. Terraform Infrastructure ✅

**Directory**: `terraform/`

**Provisions**:
- CloudSmith QA repository (`acme-pypi-qa`)
- CloudSmith Production repository (`acme-pypi-prod`)
- Service account for OIDC (`github-actions-service`)
- Repository permissions for service account
- Entitlement tokens for developers (read-only)
- Slack webhooks for QA and production events

**Benefits**:
- Version-controlled infrastructure
- Repeatable deployments
- Disaster recovery capability
- No manual UI configuration

### 3. Migration Guide ✅

**File**: `MIGRATION_GUIDE.md`

**Contents**:
- Executive summary
- Before/after comparison
- Developer workflows (install, publish, troubleshoot)
- Authentication setup
- Common tasks
- Infrastructure management
- Troubleshooting guide
- FAQ (15+ questions)
- Support channels

**Audience**: Acme Corp engineering team

### 4. Presentation Deck ✅

**File**: `PRESENTATION.md`

**Slides** (15 total):
1. Title & Overview
2. Migration Context
3. Architecture Before & After
4. Security Enhancements
5. Pipeline Walkthrough
6. Infrastructure as Code
7. Developer Experience
8. Migration Guide Highlights
9. Demo Preview
10. Key Decisions & Trade-offs
11. Success Metrics
12. Next Steps & Rollout
13. Q&A Preparation
14. Appendix - Resources
15. Thank You

**Demo Script**: `DEMO_SCRIPT.md` (detailed 10-minute walkthrough)

---

## Key Features

### Security

- ✅ **OIDC Authentication**: No long-lived credentials
- ✅ **Token Expiry**: 90-minute automatic expiration
- ✅ **Scoped Claims**: Repository and branch restrictions
- ✅ **Vulnerability Scanning**: Automatic CVE detection
- ✅ **License Compliance**: Automatic checking
- ✅ **Immutability**: Production packages cannot be deleted
- ✅ **Audit Trail**: Full deployment history

### Observability

- ✅ **Real-time Status**: GitHub Actions UI with step summaries
- ✅ **Slack Notifications**: Team alerts on QA publish and production promotion
- ✅ **CloudSmith Webhooks**: Native notifications for package events (created, synced, scanned)
- ✅ **Deployment History**: GitHub Environments track promotion history
- ✅ **CloudSmith Dashboard**: Download stats, security scans, package metadata

### Developer Experience

- ✅ **Faster Downloads**: CloudSmith CDN
- ✅ **Better Search**: Modern UI with filtering
- ✅ **Clear Docs**: Comprehensive migration guide
- ✅ **Familiar Workflow**: Same pip install process
- ✅ **No Code Changes**: Package API unchanged

---

## Architecture

### Pipeline Flow

```
GitHub Push (main)
       │
       ▼
┌────────────────┐
│  Build Package │  ← python -m build
└───────┬────────┘
        │
        ▼
┌────────────────┐
│   Run Tests    │  ← pytest with coverage
└───────┬────────┘
        │
        ▼
┌────────────────────────────────────────┐
│  Publish to QA                         │  ← cloudsmith push (OIDC auth)
│  + Slack notification to team          │
└───────┬────────────────────────────────┘
        │
        ▼
┌────────────────┐
│Manual Approval │  ← GitHub Environment (required reviewers)
└───────┬────────┘
        │
        ▼
┌────────────────────────────────────────┐
│ Promote to Prod                        │  ← cloudsmith move (QA → Prod)
│ + Slack notification to team           │
└────────────────────────────────────────┘
```

### Authentication Flow

```
GitHub Actions
      │
      ├─ Request OIDC token from GitHub
      │  (includes claims: repo, branch, actor)
      │
      ▼
CloudSmith OIDC Provider
      │
      ├─ Validate token
      ├─ Check claims match configuration
      │
      ▼
Issue short-lived JWT (~90 min)
      │
      ▼
GitHub Actions uses JWT for API calls
      │
      ▼
Token auto-expires (no cleanup needed)
```

---

## Configuration

### Required GitHub Secrets

**None!** OIDC handles authentication without secrets.

**Optional** (for fallback):
- `CLOUDSMITH_API_KEY` - If OIDC not configured

### Required GitHub Environments

- **production**
  - Required reviewers: DevOps team members
  - Deployment branch: `main`

### CloudSmith Setup

1. Organization/namespace created
2. `terraform apply` — provisions repositories, service account, OIDC provider, webhooks, entitlement tokens (fully automated)

### Workflow Variables

Edit in `.github/workflows/publish-package.yml`:

```yaml
env:
  PYTHON_VERSION: "3.11"
  PACKAGE_NAME: "acme-data-utils"
  CLOUDSMITH_NAMESPACE: "acme-4ngc"  # Your CloudSmith org namespace
  QA_REPO: "acme-pypi-qa"
  PROD_REPO: "acme-pypi-prod"
```

> **Note**: After running `terraform apply`, use the outputs to set `CLOUDSMITH_NAMESPACE` and the `oidc-service-slug` in the workflow. The service account slug is auto-generated with a suffix (e.g., `github-actions-service-y7fn`). See `terraform output github_actions_workflow_config` for exact values.

---

## Testing

### Local Build & Test

```bash
cd acme-data-utils/

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# Install dependencies
pip install --upgrade pip
pip install build pytest

# Build package
python -m build

# Install and test
pip install dist/*.whl
pytest tests/ -v
```

### Testing GitHub Actions

```bash
# Test on feature branch (won't publish)
git checkout -b test-workflow
git push origin test-workflow

# Create PR to trigger tests
# Verify build and test stages work

# Merge to main to test full flow
```

### Testing Terraform

```bash
cd terraform/

# Validate syntax
terraform validate

# Format code
terraform fmt -check

# Plan without applying
terraform plan

# Test outputs
terraform output
```

---

## Troubleshooting

### Common Issues

**Issue**: OIDC authentication fails

**Solution**: Verify OIDC provider configured in CloudSmith UI with correct claims

---

**Issue**: Package not found in CloudSmith

**Solution**: Check workflow logs, verify package built successfully, check repository permissions

---

**Issue**: GitHub Environment approval not working

**Solution**: Verify environment exists, required reviewers configured, approver has access

---

**Issue**: Terraform apply fails

**Solution**: Check API key is valid, verify permissions (Manager/Owner role), check for existing resources

---

For detailed troubleshooting, see `MIGRATION_GUIDE.md` → Troubleshooting section.

---

## Documentation

- **MIGRATION_GUIDE.md** - Comprehensive guide for developers
- **PIPELINE_ARCHITECTURE.md** - Technical architecture details
- **DEMO_SCRIPT.md** - Step-by-step demo walkthrough
- **PRESENTATION.md** - Slide deck for presentation
- **terraform/README.md** - Terraform setup instructions

---

## Support

### For This Challenge

- GitHub Issues: https://github.com/[your-repo]/issues
- Presenter: [your-email]

### CloudSmith Resources

- Docs: https://docs.cloudsmith.com
- OIDC Guide: https://docs.cloudsmith.com/authentication/setup-cloudsmith-to-authenticate-with-oidc-in-github-actions
- Terraform Provider: https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs

### GitHub Resources

- Actions Docs: https://docs.github.com/actions
- Environments: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment
- OIDC: https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect

---

## License

This challenge solution is provided as-is for evaluation purposes.

The original `acme-data-utils` package is Copyright 2026 Acme Corp (fictional) - Proprietary.

---

## Acknowledgments

**Challenge**: CloudSmith Integration Engineer (L3) Technical Challenge
**Company**: CloudSmith
**Date**: March 2026

**Key Technologies**:
- GitHub Actions
- CloudSmith
- Terraform
- Python
- OIDC

---

## Next Steps

1. **Review Deliverables**
   - [ ] Read migration guide
   - [ ] Review pipeline architecture
   - [ ] Examine Terraform code
   - [ ] Check workflow YAML

2. **Set Up Environment**
   - [ ] Create CloudSmith account
   - [ ] Run Terraform
   - [ ] Configure OIDC
   - [ ] Set up GitHub environment

3. **Test Pipeline**
   - [ ] Run workflow
   - [ ] Verify package in QA
   - [ ] Test approval flow
   - [ ] Verify promotion to production

4. **Prepare Presentation**
   - [ ] Review presentation slides
   - [ ] Practice demo script
   - [ ] Prepare Q&A responses
   - [ ] Set up backup materials

5. **Present**
   - [ ] 10-minute walkthrough
   - [ ] 10-minute live demo
   - [ ] 20-minute Q&A
   - [ ] Share repository link

---

**Thank you for reviewing this solution!**

For questions or clarifications, please reach out via [contact method].
