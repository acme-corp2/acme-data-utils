# CloudSmith Infrastructure as Code

This directory contains Terraform configuration to provision and manage Acme Corp's CloudSmith infrastructure.

## What This Provisions

This Terraform configuration creates:

1. **Two Python Repositories**:
   - `acme-pypi-qa` - QA/staging repository
   - `acme-pypi-prod` - Production repository (immutable)

2. **Service Account**:
   - `github-actions-service` - For OIDC authentication from GitHub Actions

3. **Repository Permissions**:
   - Grants service account write access to both repositories

4. **Entitlement Tokens**:
   - Read-only tokens for developers to install packages

## Prerequisites

1. **CloudSmith Account**:
   - Sign up at https://cloudsmith.com
   - Create an organization (e.g., "acme")
   - Ensure you have Manager or Owner role

2. **CloudSmith API Key**:
   - Go to https://cloudsmith.io/user/settings/api/
   - Create a new API key with full permissions
   - Save it securely (you'll use this for Terraform)

3. **Terraform**:
   - Install Terraform >= 1.0
   - Download from https://www.terraform.io/downloads

## Setup Instructions

### Step 1: Configure Variables

```bash
# Copy the example tfvars file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

Required variables to set:
- `cloudsmith_namespace` - Your CloudSmith organization name
- `cloudsmith_api_key` - Your CloudSmith API key
- `github_repository` - Your GitHub repo (e.g., "acme-corp/acme-data-utils")

### Step 2: Initialize Terraform

```bash
# Download provider plugins
terraform init
```

### Step 3: Review the Plan

```bash
# See what will be created
terraform plan
```

Expected resources:
- 2 repositories (QA + Production)
- 1 service account
- 2 repository privilege assignments
- 2 entitlement tokens

### Step 4: Apply the Configuration

```bash
# Create the infrastructure
terraform apply

# Review the changes and type 'yes' to confirm
```

### Step 5: Save the Outputs

```bash
# Display configuration values for GitHub Actions
terraform output github_actions_workflow_config

# Save all outputs to a file
terraform output > ../TERRAFORM_OUTPUTS.txt
```

### Step 6: Manual OIDC Setup

**IMPORTANT**: OIDC provider configuration must be done manually via CloudSmith UI:

1. Go to: `https://cloudsmith.io/<your-namespace>/settings/oidc/`
2. Click "Add OIDC Provider"
3. Configure:
   - **Provider**: GitHub
   - **Service Account**: `github-actions-service` (created by Terraform)
   - **Claims**:
     - `repository`: `<your-github-org>/<your-repo>` (e.g., "acme-corp/acme-data-utils")
     - `ref`: `refs/heads/main`
     - (Optional) `actor`: Restrict to specific GitHub users
4. Save the configuration

The service slug will be: `github-actions-service`

## Directory Structure

```
terraform/
├── main.tf                    # Main resource definitions
├── variables.tf               # Input variable declarations
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variable values
├── terraform.tfvars           # Your actual values (gitignored)
├── .gitignore                 # Terraform-specific gitignore
└── README.md                  # This file
```

## State Management

**Development/Testing**:
- Local state (default) is fine for this challenge

**Production**:
- Use remote state backend (S3, Terraform Cloud, etc.)
- Enable state locking
- Configure backend in `backend.tf`

Example backend configuration (create `backend.tf`):

```hcl
terraform {
  backend "s3" {
    bucket = "acme-terraform-state"
    key    = "cloudsmith/terraform.tfstate"
    region = "us-east-1"

    # State locking
    dynamodb_table = "terraform-state-lock"
  }
}
```

## Common Commands

```bash
# Initialize (first time or after adding providers)
terraform init

# Format code
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# Display specific output
terraform output qa_repository_url

# Destroy all resources (careful!)
terraform destroy
```

## Updating Infrastructure

To make changes:

1. Edit the `.tf` files
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes
4. Commit the `.tf` files to version control

## Troubleshooting

### Error: Invalid API Key

```
Error: error getting organization: HTTP 401: Unauthorized
```

**Solution**: Check your `cloudsmith_api_key` in `terraform.tfvars`

### Error: Repository Already Exists

```
Error: repository with this namespace and slug already exists
```

**Solution**:
- Either delete the existing repository in CloudSmith UI
- Or import it: `terraform import cloudsmith_repository.qa acme/acme-pypi-qa`

### Error: Insufficient Permissions

```
Error: HTTP 403: Forbidden
```

**Solution**: Ensure your API key has Manager or Owner role

## Security Best Practices

1. **Never commit `terraform.tfvars`** - It contains sensitive API keys
2. **Use environment variables** as an alternative to tfvars:
   ```bash
   export TF_VAR_cloudsmith_api_key="your-key-here"
   terraform apply
   ```
3. **Rotate API keys** regularly
4. **Use remote state** with encryption for production
5. **Enable state locking** to prevent concurrent modifications
6. **Restrict Terraform API key** to minimum required permissions

## Integration with GitHub Actions

After running Terraform, use the outputs in your GitHub Actions workflow:

```yaml
- uses: cloudsmith-io/cloudsmith-cli-action@v2
  with:
    oidc-namespace: 'acme'  # From terraform output
    oidc-service-slug: 'github-actions-service'  # From terraform output
```

To get these values:

```bash
terraform output oidc_namespace
terraform output oidc_service_slug
```

## Maintenance

### Adding a New Repository

1. Add a new `cloudsmith_repository` resource in `main.tf`
2. Add corresponding variables in `variables.tf`
3. Run `terraform plan` and `terraform apply`

### Rotating Service Account

```bash
# Terraform will handle the rotation
terraform apply -replace="cloudsmith_service.github_actions"
```

### Viewing Repository URLs

```bash
terraform output qa_repository_url
terraform output prod_repository_url
```

## Cost Considerations

CloudSmith pricing is based on:
- Storage used
- Bandwidth consumed
- Number of repositories

For current pricing: https://cloudsmith.com/pricing

This Terraform configuration creates 2 private repositories. Monitor usage via CloudSmith dashboard.

## Additional Resources

- CloudSmith Terraform Provider Docs: https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs
- CloudSmith API Documentation: https://help.cloudsmith.io/reference
- Terraform Documentation: https://www.terraform.io/docs

## Support

- CloudSmith Support: https://help.cloudsmith.io/
- Terraform Community: https://discuss.hashicorp.com/c/terraform-core/
- Acme Corp DevOps Team: devops@acme-corp.example.com
