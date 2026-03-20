#!/bin/bash
# Setup Verification Script for CloudSmith Integration Challenge
# This script validates that your environment is ready for the demo

set -e

echo "=================================="
echo "CloudSmith Integration Challenge"
echo "Setup Verification Script"
echo "=================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_CHECKS_PASSED=true

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ALL_CHECKS_PASSED=false
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "1. Checking Prerequisites..."
echo "----------------------------"

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_status 0 "Python 3 installed (version: $PYTHON_VERSION)"
else
    print_status 1 "Python 3 is NOT installed"
fi

# Check Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    print_status 0 "Git installed (version: $GIT_VERSION)"
else
    print_status 1 "Git is NOT installed"
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | python3 -c "import sys, json; print(json.load(sys.stdin)['terraform_version'])")
    print_status 0 "Terraform installed (version: $TERRAFORM_VERSION)"
else
    print_status 1 "Terraform is NOT installed"
fi

echo ""
echo "2. Checking Project Structure..."
echo "--------------------------------"

# Check workflow file
if [ -f ".github/workflows/publish-package.yml" ]; then
    print_status 0 "GitHub Actions workflow file exists"
else
    print_status 1 "GitHub Actions workflow file is MISSING"
fi

# Check Terraform files
if [ -f "terraform/main.tf" ] && [ -f "terraform/variables.tf" ] && [ -f "terraform/outputs.tf" ]; then
    print_status 0 "Terraform configuration files exist"
else
    print_status 1 "Terraform configuration files are INCOMPLETE"
fi

# Check documentation
DOC_COUNT=0
[ -f "README.md" ] && ((DOC_COUNT++))
[ -f "MIGRATION_GUIDE.md" ] && ((DOC_COUNT++))
[ -f "PRESENTATION.md" ] && ((DOC_COUNT++))
[ -f "DEMO_SCRIPT.md" ] && ((DOC_COUNT++))

if [ $DOC_COUNT -eq 4 ]; then
    print_status 0 "All documentation files exist ($DOC_COUNT/4)"
else
    print_status 1 "Documentation files incomplete ($DOC_COUNT/4)"
fi

# Check Python package
if [ -f "acme-data-utils/setup.cfg" ] && [ -f "acme-data-utils/setup.py" ]; then
    print_status 0 "Python package structure exists"
else
    print_status 1 "Python package structure is INCOMPLETE"
fi

echo ""
echo "3. Testing Python Package Build..."
echo "-----------------------------------"

cd acme-data-utils

# Check if we can import configparser
if python3 -c "import configparser" 2>/dev/null; then
    # Try to read version
    VERSION=$(python3 -c "import configparser; c = configparser.ConfigParser(); c.read('setup.cfg'); print(c['metadata']['version'])" 2>/dev/null)
    if [ ! -z "$VERSION" ]; then
        print_status 0 "Package version detected: $VERSION"
    else
        print_status 1 "Cannot read package version"
    fi
else
    print_status 1 "Python configparser module not available"
fi

# Try to build package
if python3 -m pip list | grep -q "build"; then
    print_status 0 "Python build module is installed"
else
    print_warning "Python build module not installed (run: pip install build)"
fi

cd ..

echo ""
echo "4. Validating Terraform Configuration..."
echo "-----------------------------------------"

cd terraform

if [ -f "terraform.tfvars" ]; then
    print_status 0 "terraform.tfvars file exists"
else
    print_warning "terraform.tfvars not configured yet (copy from terraform.tfvars.example)"
fi

# Validate Terraform syntax
if command -v terraform &> /dev/null; then
    if terraform validate &> /dev/null; then
        print_status 0 "Terraform configuration is valid"
    else
        print_status 1 "Terraform validation FAILED"
        terraform validate
    fi
else
    print_warning "Skipping Terraform validation (terraform not installed)"
fi

cd ..

echo ""
echo "5. Checking GitHub Actions Workflow..."
echo "---------------------------------------"

# Check if YAML is parseable (basic check)
if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/publish-package.yml'))" 2>/dev/null; then
    print_status 0 "Workflow YAML is parseable"
else
    if command -v python3 &> /dev/null && python3 -c "import yaml" &> /dev/null; then
        print_status 1 "Workflow YAML has syntax errors"
    else
        print_warning "Cannot validate YAML (PyYAML not installed)"
    fi
fi

# Check for critical workflow components
if grep -q "cloudsmith-cli-action@v2" .github/workflows/publish-package.yml; then
    print_status 0 "CloudSmith CLI action configured"
else
    print_status 1 "CloudSmith CLI action NOT found in workflow"
fi

if grep -q "oidc-namespace" .github/workflows/publish-package.yml; then
    print_status 0 "OIDC authentication configured"
else
    print_status 1 "OIDC authentication NOT configured"
fi

if grep -q "environment: production" .github/workflows/publish-package.yml; then
    print_status 0 "Production environment gate configured"
else
    print_status 1 "Production environment gate NOT configured"
fi

echo ""
echo "6. Summary"
echo "----------"

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You're ready to:"
    echo "  1. Set up your CloudSmith account"
    echo "  2. Configure terraform.tfvars"
    echo "  3. Run 'terraform apply'"
    echo "  4. Configure OIDC in CloudSmith UI"
    echo "  5. Push to GitHub and test the workflow"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo ""
    exit 1
fi
