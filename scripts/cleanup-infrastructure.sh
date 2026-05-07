#!/bin/bash
# -------------------------------------------------
# cleanup-infrastructure.sh
#
# Tears down ALL AWS resources created by Terraform.
# This is destructive and irreversible — use with care.
#
# What it destroys:
#   - EC2 Auto Scaling Group and instances
#   - Application Load Balancer
#   - ElastiCache Redis cluster
#   - CloudFront distribution and S3 bucket (frontend files deleted first)
#   - CloudWatch Log Groups, alarms, and dashboard
#   - VPC, subnets, security groups, NAT Gateway
#
# Usage:
#   chmod +x scripts/cleanup-infrastructure.sh
#   ./scripts/cleanup-infrastructure.sh
# -------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../terraform"

echo "=============================================="
echo "  StartTech Infrastructure Cleanup"
echo "=============================================="
echo ""
echo "WARNING: This will permanently destroy all AWS resources."
echo "All data in S3, ElastiCache, and CloudWatch Logs will be lost."
echo ""
read -p "Type 'destroy' to confirm: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
  echo "Aborted. Nothing was changed."
  exit 0
fi

# Determine how variables will be supplied.
# Option A (recommended locally): set TF_VAR_* environment variables before running this script.
# Option B (legacy): have a terraform.tfvars file present.
# The destroy command will pick up whichever is available.

TFVARS_FLAG=""
if [ -f "terraform.tfvars" ]; then
  TFVARS_FLAG="-var-file=terraform.tfvars"
else
  # Check that the minimum required TF_VAR_* env vars are set
  MISSING=""
  for VAR in TF_VAR_ami_id TF_VAR_docker_image TF_VAR_mongo_uri TF_VAR_frontend_bucket_name TF_VAR_alert_email; do
    [ -z "${!VAR}" ] && MISSING="$MISSING $VAR"
  done
  if [ -n "$MISSING" ]; then
    echo "ERROR: terraform.tfvars not found and these TF_VAR_* env vars are not set:"
    echo "$MISSING"
    echo ""
    echo "Either:"
    echo "  1. Copy terraform.tfvars.example to terraform.tfvars and fill in your values, OR"
    echo "  2. Export the required TF_VAR_* environment variables before running this script."
    exit 1
  fi
fi

# Step 1: Empty the S3 bucket before destroying it
# (Terraform cannot delete a non-empty S3 bucket)
echo ""
echo "Step 1/3 — Emptying S3 frontend bucket..."
# Try to get bucket name from tfvars file first, then from env var
if [ -f "terraform.tfvars" ]; then
  BUCKET_NAME=$(grep 'frontend_bucket_name' terraform.tfvars | awk -F'"' '{print $2}')
else
  BUCKET_NAME="$TF_VAR_frontend_bucket_name"
fi
if [ -n "$BUCKET_NAME" ]; then
  echo "Deleting all objects from s3://$BUCKET_NAME ..."
  aws s3 rm "s3://$BUCKET_NAME" --recursive || echo "Bucket may already be empty or not exist."
else
  echo "Could not determine bucket name — skipping S3 empty step."
fi

# Step 2: Initialize Terraform (in case .terraform/ directory is missing)
echo ""
echo "Step 2/3 — Initializing Terraform..."

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET_PREFIX="${TF_STATE_BUCKET_PREFIX:-starttech-terraform-state}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EXPECTED_STATE_BUCKET="${TF_STATE_BUCKET_PREFIX}-${ACCOUNT_ID}-${AWS_REGION}"

if aws s3api head-bucket --bucket "$EXPECTED_STATE_BUCKET" 2>/dev/null; then
  TF_STATE_BUCKET="$EXPECTED_STATE_BUCKET"
else
  # Fallback: try any bucket that matches the prefix in case naming changed.
  TF_STATE_BUCKET=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, '${TF_STATE_BUCKET_PREFIX}')].Name | [0]" \
    --output text)
fi

if [ -z "$TF_STATE_BUCKET" ] || [ "$TF_STATE_BUCKET" = "None" ]; then
  echo "ERROR: Could not find Terraform state bucket."
  echo "Expected: $EXPECTED_STATE_BUCKET"
  echo "If you deleted the state bucket, Terraform cannot discover existing resources to destroy."
  exit 1
fi

echo "Using Terraform state bucket: $TF_STATE_BUCKET"
terraform init \
  -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=$AWS_REGION"

# Step 3: Destroy all resources
echo ""
echo "Step 3/3 — Running terraform destroy..."
terraform destroy -auto-approve $TFVARS_FLAG

echo ""
echo "=============================================="
echo "  Cleanup complete. All resources destroyed."
echo "=============================================="
