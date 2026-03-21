#!/bin/bash
# sync-terraform-config.sh
#
# Reads Terraform outputs and updates the GitHub Actions workflow with the
# correct CloudSmith namespace and OIDC service slug.
#
# Run this once after 'terraform apply':
#   cd terraform && terraform apply
#   cd ..
#   bash scripts/sync-terraform-config.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/publish-package.yml"
TERRAFORM_DIR="$REPO_ROOT/terraform"

echo "Reading Terraform outputs..."

cd "$TERRAFORM_DIR"

# Check terraform is initialized
if [ ! -d ".terraform" ]; then
  echo "ERROR: Terraform not initialized. Run 'terraform init' in the terraform/ directory first."
  exit 1
fi

# Get outputs as JSON
TF_OUTPUT=$(terraform output -json 2>/dev/null)

NAMESPACE=$(echo "$TF_OUTPUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['oidc_namespace']['value'])")
SERVICE_SLUG=$(echo "$TF_OUTPUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['oidc_service_slug']['value'])")

if [ -z "$NAMESPACE" ] || [ -z "$SERVICE_SLUG" ]; then
  echo "ERROR: Could not read oidc_namespace or oidc_service_slug from Terraform outputs."
  echo "Make sure 'terraform apply' has been run successfully."
  exit 1
fi

echo "  Namespace  : $NAMESPACE"
echo "  Service slug: $SERVICE_SLUG"

cd "$REPO_ROOT"

# Update CLOUDSMITH_NAMESPACE in workflow env block
sed -i "s|CLOUDSMITH_NAMESPACE:.*|CLOUDSMITH_NAMESPACE: \"$NAMESPACE\"  # synced from terraform output|" "$WORKFLOW_FILE"

# Update oidc-service-slug in both publish-qa and promote-prod jobs
sed -i "s|oidc-service-slug:.*|oidc-service-slug: '$SERVICE_SLUG'|g" "$WORKFLOW_FILE"

echo ""
echo "Updated $WORKFLOW_FILE"
echo ""
echo "Review the changes:"
echo "  git diff .github/workflows/publish-package.yml"
echo ""
echo "Stage and commit when satisfied:"
echo "  git add .github/workflows/publish-package.yml"
echo "  git commit -m 'chore: sync workflow config from terraform output'"
