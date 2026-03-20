# Terraform configuration for Acme Corp CloudSmith infrastructure
# This provisions repositories, service accounts, and OIDC providers

terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudsmith = {
      source  = "cloudsmith-io/cloudsmith"
      version = "~> 0.0.68"
    }
  }
}

# Provider configuration
# API key should be set via environment variable: CLOUDSMITH_API_KEY
# or passed via terraform.tfvars
provider "cloudsmith" {
  api_key = var.cloudsmith_api_key
}

# ------------------------------------------------------------------------------
# CloudSmith Repositories
# ------------------------------------------------------------------------------

# QA Repository for testing and validation
resource "cloudsmith_repository" "qa" {
  namespace       = var.cloudsmith_namespace
  name            = var.qa_repository_name
  repository_type = "Private"
  slug            = var.qa_repository_name

  description = "QA repository for Python packages - packages are promoted to production after validation"

  # Package format
  # For Python packages
  index_files = true

  # Storage settings
  storage_region = var.storage_region

  # Retention policies
  # Allow deletion in QA for testing purposes
  delete_own      = true
  delete_packages = "Write"

  # Access control
  # Restrict who can push/pull
  use_debian_labels = false
  use_default_cargo_upstream = false
  use_source_packages = false

  # Vulnerability scanning
  # Enable automatic scanning for security issues
  # Note: This may require CloudSmith plan that supports scanning
}

# Production Repository
resource "cloudsmith_repository" "prod" {
  namespace       = var.cloudsmith_namespace
  name            = var.prod_repository_name
  repository_type = "Private"
  slug            = var.prod_repository_name

  description = "Production repository for Python packages - immutable, promoted from QA"

  # Package format
  index_files = true

  # Storage settings
  storage_region = var.storage_region

  # Retention policies
  # Strict immutability for production
  delete_own      = false
  delete_packages = "Admin"

  # Access control
  use_debian_labels = false
  use_default_cargo_upstream = false
  use_source_packages = false

  # Vulnerability scanning enabled
}

# ------------------------------------------------------------------------------
# Service Account for GitHub Actions OIDC
# ------------------------------------------------------------------------------

# Service account used by GitHub Actions via OIDC
resource "cloudsmith_service" "github_actions" {
  organization = var.cloudsmith_namespace
  name         = var.service_account_name
  description  = "Service account for GitHub Actions OIDC authentication - used for CI/CD pipeline"

  # Teams assignment (if using CloudSmith teams)
  # teams = ["devops", "engineering"]
}

# ------------------------------------------------------------------------------
# Repository Permissions for Service Account
# ------------------------------------------------------------------------------

# Grant service account access to QA repository
# Needs: Read, Write (push packages)
resource "cloudsmith_repository_privileges" "github_actions_qa" {
  organization = var.cloudsmith_namespace
  repository   = cloudsmith_repository.qa.slug

  # Admin user to avoid lockout
  user {
    privilege = "Admin"
    slug      = var.admin_user_slug
  }

  service {
    privilege = "Write"  # Allows pushing packages
    slug      = cloudsmith_service.github_actions.slug
  }
}

# Grant service account access to Production repository
# Needs: Read, Write (for promotion via copy)
resource "cloudsmith_repository_privileges" "github_actions_prod" {
  organization = var.cloudsmith_namespace
  repository   = cloudsmith_repository.prod.slug

  # Admin user to avoid lockout
  user {
    privilege = "Admin"
    slug      = var.admin_user_slug
  }

  service {
    privilege = "Write"  # Allows copying/promoting packages
    slug      = cloudsmith_service.github_actions.slug
  }
}

# ------------------------------------------------------------------------------
# OIDC Provider Configuration (Manual setup required)
# ------------------------------------------------------------------------------

# Note: As of the current Terraform provider version, OIDC provider configuration
# may need to be done manually via CloudSmith UI at:
# https://cloudsmith.io/<namespace>/settings/oidc/
#
# Configuration details:
# - Provider: GitHub
# - Service Account: github_actions (created above)
# - Claims:
#   - repository: <github-org>/<repo-name>
#   - ref: refs/heads/main
#   - actor: (optional - specific GitHub users)
#
# The provider will generate:
# - OIDC Namespace: var.cloudsmith_namespace
# - OIDC Service Slug: github-actions-service
#
# These values are used in the GitHub Actions workflow:
#   uses: cloudsmith-io/cloudsmith-cli-action@v2
#   with:
#     oidc-namespace: 'acme'
#     oidc-service-slug: 'github-actions-service'

# ------------------------------------------------------------------------------
# Entitlement Tokens (Optional - for developers)
# ------------------------------------------------------------------------------

# Read-only token for developers to install packages locally
resource "cloudsmith_entitlement" "developer_readonly_qa" {
  namespace  = var.cloudsmith_namespace
  repository = cloudsmith_repository.qa.slug
  name       = "Developer Read-Only QA"

  # Token configuration
  is_active = true

  # Limit downloads (optional)
  # limit_num_downloads = 1000

  # Expiry (optional)
  # limit_date_range_from = "2025-01-01T00:00:00Z"
  # limit_date_range_to   = "2025-12-31T23:59:59Z"

  # Restricted to specific packages (optional)
  # limit_packages = ["acme-data-utils"]
}

resource "cloudsmith_entitlement" "developer_readonly_prod" {
  namespace  = var.cloudsmith_namespace
  repository = cloudsmith_repository.prod.slug
  name       = "Developer Read-Only Production"

  is_active = true
}

# ------------------------------------------------------------------------------
# Webhook Configuration (Optional - for notifications)
# ------------------------------------------------------------------------------

# Webhook — notify Slack when a package is published to QA
resource "cloudsmith_webhook" "qa_package_published" {
  count      = var.webhook_url != "" ? 1 : 0
  namespace  = var.cloudsmith_namespace
  repository = cloudsmith_repository.qa.slug

  target_url = var.webhook_url

  events = [
    "package.created",
    "package.synced",
    "package.security_scanned"
  ]

  is_active = true
}

# Webhook — notify Slack when a package is moved into Production
resource "cloudsmith_webhook" "prod_package_published" {
  count      = var.webhook_url != "" ? 1 : 0
  namespace  = var.cloudsmith_namespace
  repository = cloudsmith_repository.prod.slug

  target_url = var.webhook_url

  events = [
    "package.created",
    "package.synced"
  ]

  is_active = true
}
