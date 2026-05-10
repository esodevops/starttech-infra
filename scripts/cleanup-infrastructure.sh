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

# ---- Auto-populate missing TF_VAR_* from AWS / Terraform state ----
# Any variable already exported in the environment is kept as-is.
# Missing values are pulled from SSM Parameter Store, Terraform outputs,
# or well-known AWS API calls so you don't have to export them by hand.

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET_PREFIX="${TF_STATE_BUCKET_PREFIX:-starttech-terraform-state}"

echo "Resolving Terraform variables..."

# --- alb_dns_name: skip auto-resolve (not needed for destroy, has a default) ---

# --- ami_id: use any available Amazon Linux 2 AMI if not set ---
if [ -z "$TF_VAR_ami_id" ]; then
  TF_VAR_ami_id=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-2.0.*-x86_64-gp2" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text --region "$AWS_REGION" 2>/dev/null || true)
  [ -n "$TF_VAR_ami_id" ] && echo "  ami_id        → $TF_VAR_ami_id (latest Amazon Linux 2)"
fi

# --- docker_image: read from the ASG launch template user-data ---
if [ -z "$TF_VAR_docker_image" ]; then
  LT_ID=$(aws ec2 describe-launch-templates \
    --filters "Name=launch-template-name,Values=starttech-*" \
    --query "LaunchTemplates[0].LaunchTemplateId" --output text --region "$AWS_REGION" 2>/dev/null || true)
  if [ -n "$LT_ID" ] && [ "$LT_ID" != "None" ]; then
    USER_DATA=$(aws ec2 describe-launch-template-versions \
      --launch-template-id "$LT_ID" --versions '$Latest' \
      --query "LaunchTemplateVersions[0].LaunchTemplateData.UserData" \
      --output text --region "$AWS_REGION" 2>/dev/null | base64 --decode 2>/dev/null || true)
    TF_VAR_docker_image=$(echo "$USER_DATA" | sed -nE 's/.*DOCKER_IMAGE=([^[:space:]]+).*/\1/p' | head -1 || true)
    [ -n "$TF_VAR_docker_image" ] && echo "  docker_image  → $TF_VAR_docker_image (from launch template)"
  fi
fi
# Fallback placeholder — Terraform destroy doesn't actually launch instances
[ -z "$TF_VAR_docker_image" ] && TF_VAR_docker_image="placeholder/image:latest" && \
  echo "  docker_image  → placeholder (not needed for destroy)"

# --- mongo_uri: look in SSM Parameter Store ---
if [ -z "$TF_VAR_mongo_uri" ]; then
  TF_VAR_mongo_uri=$(aws ssm get-parameter \
    --name "/starttech/prod/mongo_uri" --with-decryption \
    --query "Parameter.Value" --output text --region "$AWS_REGION" 2>/dev/null || true)
  [ -n "$TF_VAR_mongo_uri" ] && echo "  mongo_uri     → (from SSM /starttech/prod/mongo_uri)"
fi
# Fallback placeholder — not needed at destroy time
[ -z "$TF_VAR_mongo_uri" ] && TF_VAR_mongo_uri="mongodb://placeholder" && \
  echo "  mongo_uri     → placeholder (not needed for destroy)"

# --- frontend_bucket_name: look for the S3 bucket tagged with this project ---
if [ -z "$TF_VAR_frontend_bucket_name" ]; then
  TF_VAR_frontend_bucket_name=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Name,Values=starttech-frontend" \
    --resource-type-filters "s3:bucket" \
    --query "ResourceTagMappingList[0].ResourceARN" --output text --region "$AWS_REGION" 2>/dev/null \
    | sed 's|arn:aws:s3:::||' || true)
  # Fallback: list buckets and find by name prefix
  if [ -z "$TF_VAR_frontend_bucket_name" ] || [ "$TF_VAR_frontend_bucket_name" = "None" ]; then
    TF_VAR_frontend_bucket_name=$(aws s3api list-buckets \
      --query "Buckets[?starts_with(Name, 'starttech-frontend')].Name | [0]" \
      --output text 2>/dev/null || true)
  fi
  [ -n "$TF_VAR_frontend_bucket_name" ] && [ "$TF_VAR_frontend_bucket_name" != "None" ] && \
    echo "  frontend_bucket_name → $TF_VAR_frontend_bucket_name (from AWS)"
fi

# --- alert_email: look in SNS subscriptions for the starttech topic ---
if [ -z "$TF_VAR_alert_email" ]; then
  TOPIC_ARN=$(aws sns list-topics \
    --query "Topics[?contains(TopicArn, 'starttech')].TopicArn | [0]" \
    --output text --region "$AWS_REGION" 2>/dev/null || true)
  if [ -n "$TOPIC_ARN" ] && [ "$TOPIC_ARN" != "None" ]; then
    TF_VAR_alert_email=$(aws sns list-subscriptions-by-topic \
      --topic-arn "$TOPIC_ARN" \
      --query "Subscriptions[?Protocol=='email'].Endpoint | [0]" \
      --output text --region "$AWS_REGION" 2>/dev/null || true)
    [ -n "$TF_VAR_alert_email" ] && [ "$TF_VAR_alert_email" != "None" ] && \
      echo "  alert_email   → $TF_VAR_alert_email (from SNS)"
  fi
fi
[ -z "$TF_VAR_alert_email" ] || [ "$TF_VAR_alert_email" = "None" ] && \
  TF_VAR_alert_email="noreply@example.com" && \
  echo "  alert_email   → placeholder (not needed for destroy)"

# Export all resolved values so Terraform picks them up
export TF_VAR_ami_id TF_VAR_docker_image TF_VAR_mongo_uri TF_VAR_frontend_bucket_name TF_VAR_alert_email

# alb_dns_name has a default="" in variables.tf so no export needed unless set
[ -n "$TF_VAR_alb_dns_name" ] && export TF_VAR_alb_dns_name

echo ""

TFVARS_FLAG=""
if [ -f "terraform.tfvars" ]; then
  TFVARS_FLAG="-var-file=terraform.tfvars"
fi

# ---- Helper: empty one S3 bucket (objects + all versions + delete markers) ----
empty_s3_bucket() {
  local bucket="$1"
  local tmp_delete
  tmp_delete=$(mktemp /tmp/s3-delete-XXXXXX.json)
  # Ensure temp file is always removed on exit
  trap 'rm -f "$tmp_delete"' RETURN

  echo "  Emptying s3://$bucket (objects, versions, delete markers)..."

  # 1. Remove all current objects (fast path; skips versioning overhead)
  aws s3 rm "s3://$bucket" --recursive --quiet 2>/dev/null || true

  # 2. Delete versioned objects in batches of up to 1 000
  while true; do
    aws s3api list-object-versions \
      --bucket "$bucket" \
      --max-items 1000 \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null >"$tmp_delete" || break

    # Skip if the query returned null or an empty list
    if grep -q '"Key"' "$tmp_delete" 2>/dev/null; then
      aws s3api delete-objects \
        --bucket "$bucket" \
        --delete "file://$tmp_delete" \
        --output json >/dev/null 2>&1 || true
    else
      break
    fi
  done

  # 3. Delete all delete markers in batches of up to 1 000
  while true; do
    aws s3api list-object-versions \
      --bucket "$bucket" \
      --max-items 1000 \
      --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
      --output json 2>/dev/null >"$tmp_delete" || break

    if grep -q '"Key"' "$tmp_delete" 2>/dev/null; then
      aws s3api delete-objects \
        --bucket "$bucket" \
        --delete "file://$tmp_delete" \
        --output json >/dev/null 2>&1 || true
    else
      break
    fi
  done

  echo "  s3://$bucket is now empty."
}

# Step 1: Empty ALL project S3 buckets before destroying
# (Terraform cannot delete a non-empty bucket even when force_destroy = true
#  if versioning has accumulated delete markers the provider does not purge)
echo ""
echo "Step 1/3 — Emptying project S3 buckets..."

# Collect every bucket whose name starts with 'starttech-' (frontend, logs, etc.)
# The state bucket is intentionally excluded here — it is handled after destroy.
PROJECT_BUCKETS=()
while IFS= read -r bucket_name; do
  PROJECT_BUCKETS+=("$bucket_name")
done < <(
  aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, 'starttech-') && !contains(Name, 'terraform-state')].Name" \
    --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$' | grep -v '^None$' || true
)

if [ "${#PROJECT_BUCKETS[@]}" -eq 0 ]; then
  echo "  No project S3 buckets found — skipping."
else
  for BUCKET_NAME in "${PROJECT_BUCKETS[@]}"; do
    empty_s3_bucket "$BUCKET_NAME"
  done
fi

# Step 2: Initialize Terraform (in case .terraform/ directory is missing)
echo ""
echo "Step 2/3 — Initializing Terraform..."

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

# ---- Optional: remove the Terraform state bucket itself ----
# The state bucket is intentionally NOT managed by Terraform (it must
# pre-exist) so terraform destroy does not touch it.  Prompt the user
# to decide whether to delete it now.
echo ""
if [ -n "$TF_STATE_BUCKET" ] && [ "$TF_STATE_BUCKET" != "None" ]; then
  read -p "Delete Terraform state bucket '$TF_STATE_BUCKET'? This is irreversible. [y/N] " DEL_STATE
  if [[ "$DEL_STATE" =~ ^[Yy]$ ]]; then
    echo "Emptying and deleting Terraform state bucket..."
    empty_s3_bucket "$TF_STATE_BUCKET"
    aws s3api delete-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" && \
      echo "  Deleted s3://$TF_STATE_BUCKET." || \
      echo "  WARNING: Could not delete s3://$TF_STATE_BUCKET — remove it manually."
  else
    echo "State bucket kept. Remember to delete s3://$TF_STATE_BUCKET manually if no longer needed."
  fi
fi

echo ""
echo "Done."
