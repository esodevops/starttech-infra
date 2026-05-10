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

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET_PREFIX="${TF_STATE_BUCKET_PREFIX:-starttech-terraform-state}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EXPECTED_STATE_BUCKET="${TF_STATE_BUCKET_PREFIX}-${ACCOUNT_ID}-${AWS_REGION}"

if aws s3api head-bucket --bucket "$EXPECTED_STATE_BUCKET" 2>/dev/null; then
  TF_STATE_BUCKET="$EXPECTED_STATE_BUCKET"
else
  TF_STATE_BUCKET=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, '${TF_STATE_BUCKET_PREFIX}')].Name | [0]" \
    --output text)
fi

if [ -z "$TF_STATE_BUCKET" ] || [ "$TF_STATE_BUCKET" = "None" ]; then
  echo "ERROR: Could not find Terraform state bucket."
  echo "Expected: $EXPECTED_STATE_BUCKET"
  exit 1
fi

echo "Using Terraform state bucket: $TF_STATE_BUCKET"
terraform init \
  -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=$AWS_REGION"

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

# Step 5: Re-apply with fresh ALB DNS so CloudFront /api/* origin is configured
# This avoids frontend calls to /api/* falling back to S3 index.html.
echo ""
BACKEND_URL=$(terraform output -raw backend_url 2>/dev/null || true)
FRESH_ALB_DNS=$(printf '%s' "$BACKEND_URL" | sed -E 's|^https?://||; s|/.*$||; s|:[0-9]+$||')

if [ -n "$FRESH_ALB_DNS" ] && [ "$FRESH_ALB_DNS" != "None" ]; then
  echo "Applying CloudFront API routing update with ALB DNS: $FRESH_ALB_DNS"
  terraform apply -auto-approve -var-file=terraform.tfvars -var "alb_dns_name=$FRESH_ALB_DNS"
else
  echo "WARNING: Could not resolve ALB DNS from backend_url output; skipping CloudFront API routing update."
fi

echo ""
echo "Deployment complete! Key outputs:"
terraform output
