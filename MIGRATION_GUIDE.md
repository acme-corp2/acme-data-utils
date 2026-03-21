# CloudSmith Migration Guide
## Acme Corp Engineering Team

**Migration**: GitLab CI + JFrog Artifactory → GitHub Actions + CloudSmith
**Package**: `acme-data-utils`
**Date**: March 2026
**Version**: 1.0

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [What's Changing](#whats-changing)
3. [Key Improvements](#key-improvements)
4. [Before & After Comparison](#before--after-comparison)
5. [Developer Workflows](#developer-workflows)
6. [Authentication Setup](#authentication-setup)
7. [Common Tasks](#common-tasks)
8. [Infrastructure Management](#infrastructure-management)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)
11. [Getting Help](#getting-help)

---

## Executive Summary

Acme Corp is migrating from:
- **GitLab CI** → **GitHub Actions** (CI/CD platform)
- **JFrog Artifactory** → **CloudSmith** (Package registry)

This migration brings significant improvements in **security**, **observability**, and **developer experience** while maintaining the same QA-to-production promotion workflow you're familiar with.

### Timeline

- **Cutover Date**: [TBD by DevOps team]
- **Parallel Operation**: Both systems will run in parallel during transition period
- **Support**: GitLab CI + Artifactory will be deprecated 30 days after cutover

### Action Required

- ✅ Update package installation commands (see [Installing Packages](#installing-packages))
- ✅ Read this guide thoroughly
- ✅ Join training session: [TBD]
- ✅ Update your local development environment

---

## What's Changing

### CI/CD Platform: GitLab CI → GitHub Actions

| Aspect | Before (GitLab CI) | After (GitHub Actions) |
|--------|-------------------|------------------------|
| **Pipeline Location** | `.gitlab-ci.yml` | `.github/workflows/publish-package.yml` |
| **Pipeline UI** | GitLab Pipelines | GitHub Actions tab |
| **Triggers** | Push to `main` | Push to `main`, PRs |
| **Manual Approval** | Manual job | GitHub Environment approval |
| **Logs** | GitLab job logs | GitHub Actions run logs |

### Package Registry: Artifactory → CloudSmith

| Aspect | Before (Artifactory) | After (CloudSmith) |
|--------|---------------------|-------------------|
| **QA Repository** | `acme-pypi-qa` | `acme-pypi-qa` |
| **Prod Repository** | `acme-pypi-prod` | `acme-pypi-prod` |
| **Web UI** | `https://acme.jfrog.io` | `https://cloudsmith.io/~acme-4ngc` |
| **Authentication** | `.pypirc` with credentials | Entitlement tokens |
| **Package URLs** | JFrog format | CloudSmith format |

### What Stays the Same

✅ Repository names (`acme-pypi-qa`, `acme-pypi-prod`)
✅ QA-to-Production promotion workflow
✅ Manual approval gate
✅ Package versioning scheme
✅ Python package structure
✅ Testing approach (pytest)

---

## Key Improvements

### 1. Enhanced Security

**Before**: Long-lived API keys stored in GitLab CI/CD variables
- ❌ Keys never expire
- ❌ If leaked, valid indefinitely
- ❌ Manual rotation required
- ❌ Broad permissions

**After**: OIDC (OpenID Connect) keyless authentication
- ✅ No secrets to manage
- ✅ Tokens auto-expire after 90 minutes
- ✅ Automatic rotation
- ✅ Scoped to specific repository and branch
- ✅ Full audit trail

### 2. Better Observability

**New Features**:
- 📊 Real-time pipeline status in GitHub Actions UI with step summaries
- 📦 Package details visible in CloudSmith dashboard
- 🔍 Automatic vulnerability scanning (no external tools needed)
- 🔔 Slack notifications when packages are published to QA and promoted to production
- 🪝 CloudSmith-native webhooks (via Terraform) for package events (created, synced, security scanned)
- 📈 Deployment history and analytics via GitHub Environments

### 3. Built-in Security Scanning

CloudSmith automatically scans packages for:
- 🛡️ Known vulnerabilities (CVE database)
- 📜 License compliance issues
- 🔒 Malware detection

**Alerts** are surfaced in the CloudSmith UI before promotion to production.

### 4. Infrastructure as Code

- ✅ Repositories defined in Terraform
- ✅ Version-controlled configuration
- ✅ Repeatable deployments
- ✅ Disaster recovery capability
- ✅ No manual clicking in UI

### 5. Improved Developer Experience

- 🚀 Faster package downloads (CloudSmith CDN)
- 🔎 Better package search and filtering
- 📱 Modern, responsive UI
- 🔗 GitHub integration (links in PRs, Releases)
- 💬 Better error messages

---

## Before & After Comparison

### Pipeline Architecture

**Before: GitLab CI + Artifactory**

```
GitLab CI Pipeline (.gitlab-ci.yml)
├── build         - Build Python package
├── test          - Run pytest
├── publish-qa    - Upload to Artifactory QA using twine
├── gate          - Manual approval
└── promote-prod  - JFrog CLI copy to production
```

**After: GitHub Actions + CloudSmith**

```
GitHub Actions Workflow (.github/workflows/publish-package.yml)
├── build         - Build Python package
├── test          - Run pytest + coverage
├── publish-qa    - Publish to CloudSmith QA (OIDC auth) + Slack notification
├── [APPROVAL]    - GitHub Environment approval gate (required reviewers)
└── promote-prod  - cloudsmith move QA → Production + Slack notification
```

### Authentication Flow

**Before: API Keys**

```
1. DevOps admin creates API key in Artifactory
2. Key stored in GitLab CI/CD variables
3. Pipeline reads key from variables
4. Key sent with every request
5. Manual rotation every 90 days
```

**After: OIDC**

```
1. GitHub Actions requests identity token from GitHub
2. Token includes claims (repo, branch, actor)
3. CloudSmith validates token against configured claims
4. CloudSmith issues short-lived (90 min) access token
5. Token used for this workflow run only
6. Token automatically expires
```

---

## Developer Workflows

### Installing Packages

#### From QA Repository

**Purpose**: Test pre-release versions

```bash
# Set up authentication
export CLOUDSMITH_TOKEN="<get-from-devops-team>"

# Install latest version
pip install acme-data-utils \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-qa/python/simple/

# Install specific version
pip install acme-data-utils==0.2.0 \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-qa/python/simple/
```

#### From Production Repository

**Purpose**: Use stable, approved versions

```bash
# Set up authentication
export CLOUDSMITH_TOKEN="<get-from-devops-team>"

# Install latest version
pip install acme-data-utils \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/

# Install specific version
pip install acme-data-utils==0.1.0 \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
```

#### Configure pip (Recommended)

To avoid typing the index URL every time:

**Option 1**: pip.conf (Global)

```bash
# Linux/macOS: ~/.config/pip/pip.conf
# Windows: %APPDATA%\pip\pip.ini

[global]
index-url = https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/

[install]
extra-index-url = https://pypi.org/simple
```

**Option 2**: requirements.txt (Per-project)

```
# requirements.txt
--index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
--extra-index-url https://pypi.org/simple

acme-data-utils==0.1.0
pandas>=1.5.0
numpy>=1.24.0
```

### Publishing a New Version

**Before: GitLab CI**

1. Update version in `setup.cfg`
2. Commit and push to `main`
3. Go to GitLab Pipelines
4. Wait for build/test/publish-qa
5. Click "Run" on `qa-approval-gate` job
6. Wait for `promote-to-prod` job

**After: GitHub Actions**

1. Update version in `setup.cfg`
2. Commit and push to `main`
3. Go to GitHub Actions tab
4. Wait for build/test/publish-qa
5. Go to Environments → `production`
6. Click "Review deployments" → "Approve"
7. Wait for `promote-prod` job
8. GitHub Release automatically created!

### Checking Package Status

**Before: Artifactory**

- Open `https://acme.jfrog.io`
- Navigate to repository
- Search for package
- Check metadata

**After: CloudSmith**

- Open `https://cloudsmith.io/~acme-4ngc/repos/acme-pypi-prod/`
- Search for package name
- View details:
  - ✅ Download statistics
  - ✅ Vulnerability scan results
  - ✅ License information
  - ✅ Package dependencies
  - ✅ Promotion history
  - ✅ Tags (commit SHA, workflow ID)

**Or use CLI:**

```bash
# List packages
cloudsmith list packages acme/acme-pypi-prod

# Get package details
cloudsmith get package acme/acme-pypi-prod acme-data-utils/0.1.0
```

---

## Authentication Setup

### For Developers (Installing Packages)

You'll need an **entitlement token** to download packages from CloudSmith.

#### Getting Your Token

1. Ask your DevOps team for:
   - QA entitlement token (for testing)
   - Production entitlement token (for stable packages)

2. Store securely:
   ```bash
   # Add to your shell profile (~/.bashrc, ~/.zshrc)
   export CLOUDSMITH_TOKEN="your-token-here"
   ```

3. Or use in URL (less secure):
   ```bash
   pip install acme-data-utils \
     --index-url https://dl.cloudsmith.io/basic/acme:${CLOUDSMITH_TOKEN}/acme-pypi-prod/python/simple/
   ```

#### Security Best Practices

- ✅ **Never commit tokens** to version control
- ✅ Use environment variables
- ✅ Rotate tokens periodically (DevOps will notify)
- ✅ Report lost tokens immediately to DevOps
- ❌ Don't share tokens via email/Slack
- ❌ Don't paste tokens in public channels

### For CI/CD (GitHub Actions)

**OIDC is used automatically** - no tokens needed! 🎉

The workflow uses OIDC authentication:

```yaml
- uses: cloudsmith-io/cloudsmith-cli-action@v2
  with:
    oidc-namespace: 'acme'
    oidc-service-slug: 'github-actions-service'
```

No secrets to manage!

### For Manual Publishing (Emergency)

If you need to manually publish (emergency only):

1. Get API key from DevOps team (temporary, scoped)
2. Install cloudsmith-cli:
   ```bash
   pip install cloudsmith-cli
   ```
3. Authenticate:
   ```bash
   export CLOUDSMITH_API_KEY="temporary-key-here"
   ```
4. Push package:
   ```bash
   cloudsmith push python acme/acme-pypi-qa dist/acme_data_utils-0.1.0-py3-none-any.whl
   ```

**Important**: Report manual publishes to DevOps for audit trail.

---

## Common Tasks

### Task 1: Install Latest Package

```bash
# Set token
export CLOUDSMITH_TOKEN="your-token"

# Install from production
pip install acme-data-utils \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
```

### Task 2: Test a QA Version

```bash
# Create test environment
python -m venv test-env
source test-env/bin/activate  # Windows: test-env\Scripts\activate

# Install from QA
pip install acme-data-utils==0.2.0-dev \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-qa/python/simple/

# Run tests
python -c "import acme_data_utils; print(acme_data_utils.__version__)"
```

### Task 3: Check Vulnerability Status

1. Go to CloudSmith UI: `https://cloudsmith.io/~acme-4ngc/repos/acme-pypi-prod/`
2. Click on package
3. Navigate to "Security" tab
4. Review scan results

Or use CLI:

```bash
cloudsmith vulnerabilities acme/acme-pypi-prod acme-data-utils/0.1.0
```

### Task 4: Download Package for Offline Use

```bash
# Using pip
pip download acme-data-utils \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/ \
  --dest ./offline-packages/

# Or using cloudsmith CLI
cloudsmith download package acme/acme-pypi-prod acme-data-utils/0.1.0
```

### Task 5: View Package Dependencies

**Web UI**:
1. Go to package in CloudSmith
2. Click "Dependencies" tab

**CLI**:
```bash
pip show acme-data-utils
```

### Task 6: Roll Back to Previous Version

CloudSmith maintains all historical versions.

```bash
# List all versions
cloudsmith list packages acme/acme-pypi-prod --query "name:acme-data-utils"

# Install previous version
pip install acme-data-utils==0.0.9 \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
```

**Note**: Cannot delete packages from production (immutability).

---

## Infrastructure Management

### Terraform (For DevOps/Platform Team)

All CloudSmith infrastructure is managed as code using Terraform.

#### What's Managed

- ✅ Repositories (QA, Production)
- ✅ Service accounts
- ✅ Repository permissions
- ✅ Entitlement tokens
- ✅ OIDC provider configuration (partial)

#### Making Changes

```bash
# Navigate to terraform directory
cd terraform/

# Review planned changes
terraform plan

# Apply changes
terraform apply

# View outputs (repository URLs, tokens, etc.)
terraform output
```

#### Repository Structure

```
terraform/
├── main.tf                 # Resource definitions
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars        # Actual values (gitignored!)
└── README.md               # Setup guide
```

#### Disaster Recovery

All Terraform state is backed up:
- Remote state backend: [S3/Terraform Cloud]
- State versioning enabled
- Can recreate infrastructure from code

**To restore**:

```bash
terraform init
terraform plan
terraform apply
```

### Manual Configuration (CloudSmith UI)

Some settings require manual configuration:

1. **OIDC Provider** (one-time setup)
   - URL: `https://cloudsmith.io/acme/settings/oidc/`
   - Configure GitHub provider claims

2. **Webhooks** (optional)
   - URL: `https://cloudsmith.io/acme/settings/webhooks/`
   - Configure Slack/email notifications

3. **User Management** (as needed)
   - URL: `https://cloudsmith.io/acme/settings/members/`
   - Add/remove team members

4. **Entitlement Tokens** (for developers)
   - URL: `https://cloudsmith.io/acme/repos/acme-pypi-prod/entitlements/`
   - Create tokens for developer access

---

## Troubleshooting

### Issue: Cannot Install Package (401 Unauthorized)

**Symptoms**:
```
ERROR: HTTP error 401 while getting https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/acme-data-utils/
```

**Causes**:
- Missing or invalid entitlement token
- Token expired
- Wrong repository URL

**Solutions**:
1. Check token is set:
   ```bash
   echo $CLOUDSMITH_TOKEN
   ```
2. Use token in URL:
   ```bash
   pip install acme-data-utils \
     --index-url https://dl.cloudsmith.io/basic/acme:YOUR-TOKEN-HERE/acme-pypi-prod/python/simple/
   ```
3. Request new token from DevOps

### Issue: Package Not Found (404)

**Symptoms**:
```
ERROR: Could not find a version that satisfies the requirement acme-data-utils==0.2.0
```

**Causes**:
- Package not published yet
- Version doesn't exist
- Wrong repository (QA vs Production)

**Solutions**:
1. Check package exists in CloudSmith UI
2. List available versions:
   ```bash
   pip index versions acme-data-utils \
     --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
   ```
3. Check if package is in QA instead of Production

### Issue: GitHub Actions Workflow Fails (OIDC)

**Symptoms**:
```
Error: Failed to authenticate with OIDC
```

**Causes**:
- OIDC provider not configured in CloudSmith
- Claims mismatch (wrong repo/branch)
- Service account permissions issue

**Solutions**:
1. Verify OIDC provider settings in CloudSmith UI
2. Check claims match:
   - Repository: `acme-corp/acme-data-utils`
   - Ref: `refs/heads/main`
3. Verify service account has write permissions
4. Contact DevOps team

### Issue: Package Promotion Fails

**Symptoms**:
```
Error: Package not found in source repository
```

**Causes**:
- Package not yet published to QA
- Wrong version specified
- Timing issue (package still processing)

**Solutions**:
1. Verify package exists in QA repository
2. Wait 1-2 minutes for CloudSmith processing
3. Check CloudSmith logs for errors
4. Retry workflow

### Issue: Vulnerability Scan Fails Promotion

**Symptoms**:
```
Error: Package failed security scan
```

**Causes**:
- Package has known vulnerabilities
- License compliance issue
- Policy violation

**Solutions**:
1. Review scan results in CloudSmith UI
2. Update dependencies to fix vulnerabilities
3. Request policy exemption (if acceptable risk)
4. Publish new version with fixes

---

## FAQ

### Q: Can I still use PyPI packages alongside acme-data-utils?

**A**: Yes! Use `--extra-index-url`:

```bash
pip install acme-data-utils requests \
  --index-url https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/ \
  --extra-index-url https://pypi.org/simple
```

Or configure in `pip.conf`:
```ini
[global]
index-url = https://dl.cloudsmith.io/basic/acme-4ngc/acme-pypi-prod/python/simple/
extra-index-url = https://pypi.org/simple
```

### Q: What happens to packages in Artifactory?

**A**: Packages will be migrated to CloudSmith during transition period. Old Artifactory instance will remain read-only for 90 days after cutover for historical access.

### Q: How do I know which version is in production?

**A**:
- Check CloudSmith UI: `https://cloudsmith.io/~acme-4ngc/repos/acme-pypi-prod/`
- Check GitHub Releases: `https://github.com/acme-corp/acme-data-utils/releases`
- Use CLI:
  ```bash
  cloudsmith list packages acme/acme-pypi-prod --query "name:acme-data-utils"
  ```

### Q: Can I delete a package I published by mistake?

**A**:
- **QA**: Yes, contact DevOps team
- **Production**: No (immutability policy)
- **Workaround**: Publish new version, update dependencies

### Q: How long are packages retained?

**A**:
- **QA**: 90 days (configurable)
- **Production**: Indefinitely
- Historical versions always accessible

### Q: Do I need to change my code?

**A**: No! The `acme-data-utils` package API remains unchanged. Only installation commands change.

### Q: What about private dependencies?

**A**: If `acme-data-utils` depends on other internal packages, they should also be published to CloudSmith. Update `setup.cfg` to reference CloudSmith URLs if needed.

### Q: Can I use CloudSmith from CI/CD outside GitHub?

**A**: Yes! Use API keys or entitlement tokens. OIDC is available for select CI/CD platforms. Contact DevOps for setup.

### Q: What if CloudSmith is down?

**A**:
- CloudSmith has 99.9% SLA
- CDN provides redundancy
- During transition, Artifactory remains available as fallback
- Offline package cache recommended for critical systems

### Q: How do I report a security issue?

**A**: Contact security@acme-corp.com immediately. Do not share details in public channels.

---

## Getting Help

### Support Channels

1. **DevOps Team** (Primary)
   - Email: devops@acme-corp.example.com
   - Slack: #devops-support
   - Office hours: Mon-Fri, 9 AM - 5 PM PST

2. **Documentation**
   - This migration guide
   - CloudSmith Docs: https://docs.cloudsmith.com
   - GitHub Actions Docs: https://docs.github.com/actions

3. **Training Sessions**
   - Weekly Q&A: Wednesdays, 2 PM PST
   - Recorded sessions: [Internal wiki link]

4. **Emergency**
   - On-call DevOps: [PagerDuty link]
   - Use for production outages only

### Useful Links

- **CloudSmith Web UI**: https://cloudsmith.io/~acme-4ngc
- **GitHub Repository**: https://github.com/acme-corp/acme-data-utils
- **GitHub Actions**: https://github.com/acme-corp/acme-data-utils/actions
- **Terraform Code**: `terraform/` directory
- **Migration Guide** (this doc): `MIGRATION_GUIDE.md`
- **Architecture Docs**: `PIPELINE_ARCHITECTURE.md`

### Reporting Issues

Use GitHub Issues for:
- ✅ CI/CD pipeline issues
- ✅ Feature requests
- ✅ Documentation improvements
- ✅ Bug reports in acme-data-utils

**Template**:
```
**Issue**: [Brief description]
**Environment**: [QA/Production/Local]
**Steps to Reproduce**: [Steps]
**Expected**: [What should happen]
**Actual**: [What actually happens]
**Logs**: [Paste relevant logs]
```

---

## Feedback

We value your feedback! Help us improve this migration.

**Quick Survey**: [Survey link]

**Topics**:
- Was this guide helpful?
- What's unclear?
- What's missing?
- Suggestions for improvement?

**Contact**: devops@acme-corp.example.com

---

**Last Updated**: March 19, 2026
**Version**: 1.0
**Maintained By**: Acme Corp DevOps Team
