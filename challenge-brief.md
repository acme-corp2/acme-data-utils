# Integration Engineer (L3) — Technical Challenge

## Acme Corp: Registry & Pipeline Migration

---

## 1. Introduction

**Acme Corp** is a mid-size data analytics company that builds and ships a suite of
internal Python libraries used across their engineering organization. Their
flagship package, `acme-data-utils`, is published as a Python package to an
internal package registry.

Acme is undertaking two simultaneous migrations:

1. **Package Registry** — From **JFrog Artifactory** to **Cloudsmith**
2. **CI/CD Platform** — From **GitLab CI** to **GitHub Actions**

They currently operate a QA-gate promotion workflow: packages are first published
to a QA repository, undergo validation, and are then promoted to a production
repository after manual approval.

You have been assigned as the Cloudsmith Integration Engineer leading this
migration.

---

## 2. The Existing Setup

### Current Architecture

- **CI/CD**: GitLab CI (self-hosted runners, Docker executor)
- **Package Registry**: JFrog Artifactory (on-prem), with two PyPI repositories:
  - `acme-pypi-qa` — QA/staging packages
  - `acme-pypi-prod` — Production-approved packages
- **Package**: `acme-data-utils` — a Python package used across the
  engineering organization
- **Flow**: Build → Test → Publish to QA → Manual gate → Promote to Prod

### The Provided GitLab Pipeline

Below is Acme's current `.gitlab-ci.yml`. Your task is to migrate this to GitHub
Actions while targeting Cloudsmith as the package registry.

```yaml
# Acme Corp — acme-data-utils CI/CD Pipeline
# GitLab CI + JFrog Artifactory

stages:
  - build
  - test
  - publish-qa
  - gate
  - promote-prod

variables:
  ARTIFACTORY_URL: "https://acme.jfrog.io"
  ARTIFACTORY_USER: $ARTIFACTORY_USER       # CI/CD variable
  ARTIFACTORY_API_KEY: $ARTIFACTORY_API_KEY  # CI/CD variable
  QA_REPO: "acme-pypi-qa"
  PROD_REPO: "acme-pypi-prod"
  PYTHON_VERSION: "3.11"
  PACKAGE_NAME: "acme-data-utils"

default:
  image: python:${PYTHON_VERSION}
  before_script:
    - pip install --upgrade pip setuptools wheel build twine

# ---------------------------------------------------------------------------
# Stage: build
# ---------------------------------------------------------------------------
build-package:
  stage: build
  script:
    - python -m build
    - ls -la dist/
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

# ---------------------------------------------------------------------------
# Stage: test
# ---------------------------------------------------------------------------
run-tests:
  stage: test
  dependencies:
    - build-package
  script:
    - pip install dist/*.whl
    - pip install pytest
    - pytest tests/ -v
  artifacts:
    reports:
      junit: report.xml
    when: always

# ---------------------------------------------------------------------------
# Stage: publish-qa
# ---------------------------------------------------------------------------
publish-to-qa:
  stage: publish-qa
  dependencies:
    - build-package
  script:
    - |
      cat > ~/.pypirc << EOF
      [distutils]
      index-servers = artifactory-qa

      [artifactory-qa]
      repository: ${ARTIFACTORY_URL}/api/pypi/${QA_REPO}
      username: ${ARTIFACTORY_USER}
      password: ${ARTIFACTORY_API_KEY}
      EOF
    - twine upload -r artifactory-qa dist/*
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# ---------------------------------------------------------------------------
# Stage: gate  (manual approval)
# ---------------------------------------------------------------------------
qa-approval-gate:
  stage: gate
  script:
    - echo "QA gate passed — approved for production promotion."
  when: manual
  allow_failure: false
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# ---------------------------------------------------------------------------
# Stage: promote-prod
# ---------------------------------------------------------------------------
promote-to-prod:
  stage: promote-prod
  image: releases-docker.jfrog.io/jfrog/jfrog-cli-v2-jf:latest
  dependencies: []
  script:
    - jf config add acme-server
        --url="${ARTIFACTORY_URL}"
        --user="${ARTIFACTORY_USER}"
        --apikey="${ARTIFACTORY_API_KEY}"
        --interactive=false
    - |
      jf rt cp \
        "${QA_REPO}/${PACKAGE_NAME}/*" \
        "${PROD_REPO}/${PACKAGE_NAME}/" \
        --flat=true
    - echo "Package promoted from ${QA_REPO} to ${PROD_REPO}."
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

### What to Note

- The pipeline uses **long-lived API keys** stored as CI/CD variables for
  Artifactory authentication.
- The promotion step uses the JFrog CLI to **copy** packages between repos.
- The QA gate is a **manual job** that must be triggered by a human.

---

## 3. Your Objectives

Migrate the pipeline to GitHub Actions + Cloudsmith, considering the following
areas:

- **Authentication** — How should the new pipeline authenticate with
  Cloudsmith?
- **Observability** — How will developers know when their packages are available in different environments?
- **QA Gate & Promotion** — How will you replicate the QA-to-production
  promotion workflow using Cloudsmith's capabilities?
- **Infrastructure as Code** — Where supported, how can you manage Cloudsmith
  configuration (repositories, permissions, settings) as code rather than
  manual UI configuration?

You are expected to research Cloudsmith's platform and make informed decisions
about the best approach for each area. Be prepared to explain your choices
during the live session.

---

## 4. Deliverables

You are expected to produce four deliverables:

### 4.1 Working GitHub Actions Pipeline

One or more `.github/workflows/*.yml` files that replicate the existing
pipeline's functionality using GitHub Actions and Cloudsmith. Study the
provided GitLab CI configuration to understand what the pipeline does and
ensure your migration covers the equivalent stages.

### 4.2 Infrastructure Configuration

Provide infrastructure-as-code definitions using Terraform for managing
Cloudsmith resources (repositories, service accounts, OIDC providers, etc.).
Demonstrate how Acme's Cloudsmith infrastructure should be provisioned and
maintained as code rather than through manual configuration.

### 4.3 Migration Guide

A written document (Markdown, PDF, or similar) aimed at Acme Corp's engineering
team, covering:

- Key differences between the old (GitLab + Artifactory) and new (GitHub Actions
  + Cloudsmith) setup
- Step-by-step instructions for common developer workflows
- Authentication approach
- Infrastructure management approach (manual vs. IaC)
- Any additional recommendations

### 4.4 Presentation Deck

A short slide deck (5–8 slides) that you will present live covering the above two points.

---

## 5. Constraints & Notes

### Cloudsmith Account

- Sign up for a **free trial** at [https://cloudsmith.com](https://cloudsmith.com)
  and create your own organization.
- Set up the repositories and any authentication configuration you need for
  the challenge. This is part of the assessment — we want to see how you
  navigate the platform independently.

### Dummy Package

- The provided `acme-data-utils` zip contains a minimal Python package.
- Build it with: `python -m build`
- Test it with: `pip install ".[test]" && pytest tests/`

### Cloudsmith Documentation

- **Docs**: [https://docs.cloudsmith.com](https://docs.cloudsmith.com)
- **CLI Action (GitHub)**: [https://github.com/cloudsmith-io/cloudsmith-cli-action](https://github.com/cloudsmith-io/cloudsmith-cli-action)
- **Terraform Provider**: [https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs](https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs)

### What You Will Be Judged On

- **Technical depth** — Do your solutions demonstrate understanding?
- **Security posture** — Have you improved on the original pipeline's security?
- **Completeness** — Does the pipeline actually work end-to-end?
- **Communication** — Can you explain your decisions clearly to both technical
  and non-technical stakeholders?
- **Pragmatism** — Have you made sensible trade-offs given time constraints?

### What You Will NOT Be Judged On

- Visual polish of the slide deck
- Minor syntax errors that wouldn't affect a production deployment
- The speed at which you completed the work

---

## 6. Logistics

### Timeline

You have **3 working days** from when you receive this document to complete
the deliverables.

### Presentation Format

| Segment | Duration | Description |
|---------|----------|-------------|
| Walkthrough | 10 minutes | Walk us through your pipeline and migration guide |
| Live Demo | 10 minutes | Demonstrate the pipeline running (or walk through the output) |
| Q&A | 20 minutes | We'll ask about your design decisions and probe technical depth |

### Submission

- **Before the session**: Share your GitHub repository link (or zip) and
  presentation deck with us at least **2 hours** before the scheduled
  presentation time.
- Share via the email address provided in your calendar invite.

### Questions?

If you have **logistical** questions (access issues, scheduling), contact the
person who sent you this challenge.

**Technical** questions about the challenge itself should be answered through
your own research — this is part of the assessment. We are looking at how you
approach unfamiliar problems, not just whether you arrive at a perfect answer.

---

*Good luck! We look forward to seeing your approach.*
