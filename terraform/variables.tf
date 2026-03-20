# Variables for CloudSmith Terraform configuration

# ------------------------------------------------------------------------------
# CloudSmith Organization/Namespace
# ------------------------------------------------------------------------------

variable "cloudsmith_namespace" {
  description = "CloudSmith organization/namespace name"
  type        = string

  # Example: "acme" or "acme-corp"
  # This should match your CloudSmith organization name
}

# ------------------------------------------------------------------------------
# Authentication
# ------------------------------------------------------------------------------

variable "cloudsmith_api_key" {
  description = "CloudSmith API key for Terraform provider authentication"
  type        = string
  sensitive   = true

  # This should be set via:
  # 1. Environment variable: export CLOUDSMITH_API_KEY="your-key-here"
  # 2. terraform.tfvars: cloudsmith_api_key = "your-key-here"
  # 3. CLI: terraform apply -var="cloudsmith_api_key=your-key-here"
  #
  # To generate an API key:
  # 1. Log in to CloudSmith
  # 2. Go to Settings > API Keys
  # 3. Create a new API key with appropriate permissions
}

# ------------------------------------------------------------------------------
# Repository Configuration
# ------------------------------------------------------------------------------

variable "qa_repository_name" {
  description = "Name of the QA repository for staging packages"
  type        = string
  default     = "acme-pypi-qa"

  # This matches the original JFrog Artifactory repository name
}

variable "prod_repository_name" {
  description = "Name of the production repository"
  type        = string
  default     = "acme-pypi-prod"

  # This matches the original JFrog Artifactory repository name
}

variable "storage_region" {
  description = "Storage region for repositories (e.g., us-east-1, eu-west-1)"
  type        = string
  default     = "default"

  # Options depend on CloudSmith plan and available regions
  # Use "default" to let CloudSmith choose the optimal region
}

# ------------------------------------------------------------------------------
# Service Account Configuration
# ------------------------------------------------------------------------------

variable "service_account_name" {
  description = "Name of the service account for GitHub Actions OIDC"
  type        = string
  default     = "github-actions-service"

  # This service account will be used by GitHub Actions workflows
  # via OIDC authentication (keyless)
}

variable "admin_user_slug" {
  description = "Admin user slug for repository privileges (to avoid lockout)"
  type        = string

  # This should be your CloudSmith username slug
  # You can find it by going to your CloudSmith profile
  # Example: "kapil-sharma", "john-doe"
}

# ------------------------------------------------------------------------------
# GitHub Repository Configuration (for OIDC claims)
# ------------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub repository in format 'org/repo' for OIDC claims"
  type        = string

  # Example: "acme-corp/acme-data-utils"
  # This is used to restrict OIDC authentication to a specific repo
}

variable "github_ref" {
  description = "GitHub ref (branch) allowed for OIDC authentication"
  type        = string
  default     = "refs/heads/main"

  # Restrict OIDC tokens to only be issued from the main branch
}

# ------------------------------------------------------------------------------
# Optional Webhook Configuration
# ------------------------------------------------------------------------------

variable "webhook_url" {
  description = "Webhook URL for notifications (e.g., Slack webhook)"
  type        = string
  default     = ""

  # Leave empty to disable webhooks
  # Example Slack webhook: "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX"
}

# ------------------------------------------------------------------------------
# Tags for Organization
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to resources for organization and billing"
  type        = map(string)
  default = {
    project     = "acme-data-utils"
    environment = "production"
    managed_by  = "terraform"
    team        = "devops"
  }
}
