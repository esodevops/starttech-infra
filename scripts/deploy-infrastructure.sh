#!/bin/bash
# -------------------------------------------------
# deploy-infrastructure.sh
#
# Simple wrapper around `terraform apply`.
# Run this from your local machine when you want
# to deploy or update the infrastructure manually.
#
# Usage:
#   chmod +x scripts/deploy-infrastructure.sh
#   ./scripts/deploy-infrastructure.sh
# -------------------------------------------------

set -e  # Exit immediately on any error

# Change to the terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../terraform"

echo "=== StartTech Infrastructure Deployment ==="
echo ""

# Make sure terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  echo "ERROR: terraform.tfvars not found."
  echo "Copy terraform.tfvars.example to terraform.tfvars and fill in your values."
  exit 1
fi

# Step 1: Initialize (download providers, configure S3 backend)
echo "Step 1/3 — Initializing Terraform..."
terraform init

# Step 2: Show what will change
echo ""
echo "Step 2/3 — Planning changes..."
terraform plan -var-file=terraform.tfvars -out=tfplan

# Step 3: Ask for confirmation before applying
echo ""
read -p "Apply these changes? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

# Step 4: Apply
echo ""
echo "Step 3/3 — Applying changes..."
terraform apply tfplan

echo ""
echo "Deployment complete! Key outputs:"
terraform output
