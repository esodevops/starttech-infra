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

# Make sure terraform.tfvars exists (needed to identify which resources to destroy)
if [ ! -f "terraform.tfvars" ]; then
  echo "ERROR: terraform.tfvars not found."
  echo "Copy terraform.tfvars.example to terraform.tfvars and fill in your values."
  exit 1
fi

# Step 1: Empty the S3 bucket before destroying it
# (Terraform cannot delete a non-empty S3 bucket)
echo ""
echo "Step 1/3 — Emptying S3 frontend bucket..."
BUCKET_NAME=$(grep 'frontend_bucket_name' terraform.tfvars | awk -F'"' '{print $2}')
if [ -n "$BUCKET_NAME" ]; then
  echo "Deleting all objects from s3://$BUCKET_NAME ..."
  aws s3 rm "s3://$BUCKET_NAME" --recursive || echo "Bucket may already be empty or not exist."
else
  echo "Could not determine bucket name from terraform.tfvars — skipping S3 empty step."
fi

# Step 2: Initialize Terraform (in case .terraform/ directory is missing)
echo ""
echo "Step 2/3 — Initializing Terraform..."
terraform init

# Step 3: Destroy all resources
echo ""
echo "Step 3/3 — Running terraform destroy..."
terraform destroy -auto-approve -var-file=terraform.tfvars

echo ""
echo "=============================================="
echo "  Cleanup complete. All resources destroyed."
echo "=============================================="
