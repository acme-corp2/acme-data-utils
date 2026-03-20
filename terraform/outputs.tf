# Outputs for CloudSmith Terraform configuration

# ------------------------------------------------------------------------------
# Repository Information
# ------------------------------------------------------------------------------

output "qa_repository_url" {
  description = "URL to the QA repository in CloudSmith"
  value       = "https://cloudsmith.io/~${var.cloudsmith_namespace}/repos/${cloudsmith_repository.qa.slug}/"
}

output "qa_repository_name" {
  description = "Full name of the QA repository"
  value       = "${var.cloudsmith_namespace}/${cloudsmith_repository.qa.slug}"
}

output "qa_repository_slug" {
  description = "Slug of the QA repository"
  value       = cloudsmith_repository.qa.slug
}

output "prod_repository_url" {
  description = "URL to the production repository in CloudSmith"
  value       = "https://cloudsmith.io/~${var.cloudsmith_namespace}/repos/${cloudsmith_repository.prod.slug}/"
}

output "prod_repository_name" {
  description = "Full name of the production repository"
  value       = "${var.cloudsmith_namespace}/${cloudsmith_repository.prod.slug}"
}

output "prod_repository_slug" {
  description = "Slug of the production repository"
  value       = cloudsmith_repository.prod.slug
}

# ------------------------------------------------------------------------------
# Service Account Information
# ------------------------------------------------------------------------------

output "service_account_slug" {
  description = "Slug of the service account for use in GitHub Actions OIDC"
  value       = cloudsmith_service.github_actions.slug
}

output "service_account_name" {
  description = "Name of the service account"
  value       = cloudsmith_service.github_actions.name
}

# ------------------------------------------------------------------------------
# OIDC Configuration (for GitHub Actions workflow)
# ------------------------------------------------------------------------------

output "oidc_namespace" {
  description = "OIDC namespace for GitHub Actions workflow configuration"
  value       = var.cloudsmith_namespace
}

output "oidc_service_slug" {
  description = "OIDC service slug for GitHub Actions workflow configuration"
  value       = cloudsmith_service.github_actions.slug
}

output "github_actions_workflow_config" {
  description = "Configuration values for GitHub Actions workflow"
  value = {
    oidc_namespace   = var.cloudsmith_namespace
    oidc_service_slug = cloudsmith_service.github_actions.slug
    qa_repo_name     = "${var.cloudsmith_namespace}/${cloudsmith_repository.qa.slug}"
    prod_repo_name   = "${var.cloudsmith_namespace}/${cloudsmith_repository.prod.slug}"
  }
}

# ------------------------------------------------------------------------------
# Entitlement Token IDs (for developer access)
# ------------------------------------------------------------------------------

output "developer_qa_token_id" {
  description = "Entitlement token ID for QA repository (developers can use this to install packages)"
  value       = cloudsmith_entitlement.developer_readonly_qa.id
  sensitive   = true
}

output "developer_prod_token_id" {
  description = "Entitlement token ID for production repository"
  value       = cloudsmith_entitlement.developer_readonly_prod.id
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Installation Instructions
# ------------------------------------------------------------------------------

output "pip_install_instructions_qa" {
  description = "Instructions for installing packages from QA repository"
  value = <<-EOT
    To install packages from the QA repository:

    1. Set up authentication with entitlement token:
       export CLOUDSMITH_TOKEN="<get-token-from-cloudsmith-ui>"

    2. Install package:
       pip install acme-data-utils \
         --index-url https://dl.cloudsmith.io/basic/${var.cloudsmith_namespace}/${cloudsmith_repository.qa.slug}/python/simple/

    Or configure in pip.conf:

    [global]
    index-url = https://dl.cloudsmith.io/basic/${var.cloudsmith_namespace}/${cloudsmith_repository.qa.slug}/python/simple/
  EOT
}

output "pip_install_instructions_prod" {
  description = "Instructions for installing packages from production repository"
  value = <<-EOT
    To install packages from the production repository:

    1. Set up authentication with entitlement token:
       export CLOUDSMITH_TOKEN="<get-token-from-cloudsmith-ui>"

    2. Install package:
       pip install acme-data-utils \
         --index-url https://dl.cloudsmith.io/basic/${var.cloudsmith_namespace}/${cloudsmith_repository.prod.slug}/python/simple/

    Or configure in pip.conf:

    [global]
    index-url = https://dl.cloudsmith.io/basic/${var.cloudsmith_namespace}/${cloudsmith_repository.prod.slug}/python/simple/
  EOT
}

# ------------------------------------------------------------------------------
# Next Steps
# ------------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps after Terraform apply"
  value = <<-EOT
    ✅ CloudSmith infrastructure has been provisioned!

    Next steps:

    1. OIDC Provider Setup (Manual):
       - Go to: https://cloudsmith.io/${var.cloudsmith_namespace}/settings/oidc/
       - Add OIDC provider for GitHub
       - Service Account: ${cloudsmith_service.github_actions.slug}
       - Claims to configure:
         * repository: ${var.github_repository}
         * ref: ${var.github_ref}

    2. GitHub Secrets Configuration:
       - No secrets needed if using OIDC! ✅
       - (Optional fallback) Add CLOUDSMITH_API_KEY as GitHub secret

    3. Update GitHub Actions Workflow:
       - Set oidc-namespace: ${var.cloudsmith_namespace}
       - Set oidc-service-slug: ${cloudsmith_service.github_actions.slug}

    4. Test the Pipeline:
       - Push to main branch
       - Verify package published to QA: ${cloudsmith_repository.qa.slug}
       - Approve promotion
       - Verify package in production: ${cloudsmith_repository.prod.slug}

    5. Developer Access:
       - Share entitlement tokens from CloudSmith UI
       - Update team documentation with pip install instructions

    Repository URLs:
    - QA: https://cloudsmith.io/~${var.cloudsmith_namespace}/repos/${cloudsmith_repository.qa.slug}/
    - Prod: https://cloudsmith.io/~${var.cloudsmith_namespace}/repos/${cloudsmith_repository.prod.slug}/
  EOT
}
