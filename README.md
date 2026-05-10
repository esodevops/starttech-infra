# Cross-Repository Integration

### Connecting Infrastructure and Application Repos

1. Deploy infrastructure using this repo. After a successful deploy, Terraform will output the CloudFront and ALB URLs.
2. Use the provided secret sync scripts or GitHub Actions to propagate these outputs to the application repo as GitHub secrets (e.g., `REACT_APP_API_URL`, `S3_BUCKET_NAME`, `CLOUDFRONT_DISTRIBUTION_ID`).
3. The application repo will consume these secrets for its own CI/CD and deployment.

### MongoDB Atlas Integration

1. Create a MongoDB Atlas API key (Project Owner).
2. Add `ATLAS_PUBLIC_KEY`, `ATLAS_PRIVATE_KEY`, and `ATLAS_PROJECT_ID` as GitHub secrets.
3. The CI workflow will update the Atlas IP Access List with the current NAT Gateway IP and remove old ones automatically.

### Docker Image Integration

1. The backend Docker image is built and pushed to Docker Hub by the application repo's CI/CD pipeline.
2. EC2 instances (via user data or ASG launch template) pull the latest image using Docker Hub credentials from secrets.

### IAM and Secret Propagation

- Use the provided least-privilege IAM policies for CI/CD users and runners.
- Use the secret sync scripts to keep both repos' secrets in sync after infra changes.

# Additional Documentation

- See [ARCHITECTURE.md](ARCHITECTURE.md) for system architecture documentation.
- See [RUNBOOK.md](RUNBOOK.md) for operations and troubleshooting guide.
  [![Infrastructure Deploy](https://github.com/esodevops/starttech-infra/actions/workflows/infrastructure-deploy.yml/badge.svg)](https://github.com/esodevops/starttech-infra/actions/workflows/infrastructure-deploy.yml)

# StartTech Infrastructure

Terraform code and CI/CD pipeline for the StartTech full-stack application.

## What This Repo Does

It provisions all AWS infrastructure needed to run the application:

| Component        | AWS Service                                        |
| ---------------- | -------------------------------------------------- |
| Backend API      | EC2 Auto Scaling Group + Application Load Balancer |
| Frontend         | S3 + CloudFront CDN                                |
| Cache / Sessions | ElastiCache Redis                                  |
| Database         | MongoDB Atlas (external)                           |
| Logging          | CloudWatch Logs                                    |
| Alerting         | CloudWatch Alarms → SNS → Email                    |

---

## Repository Structure

```
starttech-infra/
├── .github/workflows/
│   └── infrastructure-deploy.yml   # CI/CD: runs terraform plan on PRs, apply on merge
├── terraform/
│   ├── main.tf                     # Root: wires all modules together
│   ├── variables.tf                # All input variables
│   ├── outputs.tf                  # Prints URLs after deploy
│   ├── terraform.tfvars.example    # Copy this to terraform.tfvars
│   └── modules/
│       ├── networking/             # VPC, subnets, security groups
│       ├── compute/                # ALB, EC2 launch template, ASG, scaling policies
│       ├── storage/                # S3, CloudFront, ElastiCache Redis
│       └── monitoring/             # CloudWatch logs, alarms, SNS alerts
├── scripts/
│   └── deploy-infrastructure.sh   # Manual deploy helper
└── monitoring/
    ├── cloudwatch-dashboard.json   # Dashboard definition
    ├── alarm-definitions.json      # Alarm reference
    └── log-insights-queries.txt    # Useful log queries
```

---

## One-time Setup

### 1. Create the Terraform state bucket

Terraform stores its state in S3. Create this bucket once manually (before running `terraform init`):

```bash
aws s3api create-bucket \
  --bucket starttech-terraform-state \
  --region us-east-1
```

### 2. Create `terraform.tfvars`

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your real values
```

### 3. Add GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions** and add:

| Secret                  | Description                     |
| ----------------------- | ------------------------------- |
| `AWS_ACCESS_KEY_ID`     | IAM user access key             |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key             |
| `MONGO_URI`             | MongoDB Atlas connection string |

---

## Deploying

**Via GitHub Actions (recommended):**

- Open a PR → pipeline runs `terraform plan` and posts the diff as a comment
- Merge to `main` → pipeline runs `terraform apply` automatically

**Manually from your laptop:**

```bash
chmod +x scripts/deploy-infrastructure.sh
./scripts/deploy-infrastructure.sh
```

---

## IAM Policy (Least Privilege)

Use the first-pass CI/deploy policy in:

- `iam/starttech-infra-ci-policy.json`

This policy is tailored to the resources and scripts in this repository (Terraform modules + deploy/cleanup helpers), including:

- VPC, subnets, route tables, IGW, NAT gateway, EIP, and security groups
- ALB, listeners, target groups, EC2 launch templates, and Auto Scaling
- S3 frontend bucket and Terraform state bucket operations
- CloudFront distribution and origin access control
- ElastiCache Redis cluster and subnet group
- CloudWatch log groups, alarms, dashboards, and SNS alerts
- IAM role/profile management needed for EC2 instance profile and `iam:PassRole`
- Read actions used by helper scripts (`ssm:GetParameter`, tagging API lookups, topic/subscription reads)

### Safe Migration From AdministratorAccess

1. Create a new IAM user/role for infra deploy using the policy above.
2. Keep your current working admin credentials as rollback.
3. Test on a branch/PR first (`terraform plan`), then run apply on `main`.
4. If successful, switch GitHub Actions secrets to the new principal.
5. After stable runs, remove AdministratorAccess from the old principal.

---

## After First Deploy

Terraform will print:

```
frontend_url  = "https://xxxxx.cloudfront.net"
backend_url   = "http://starttech-alb-xxxxx.us-east-1.elb.amazonaws.com"
```

Test the backend health check:

```bash
curl http://<backend_url>/health
# Expected: {"status":"ok"}
```

---

## Destroying Everything

```bash
cd terraform
terraform destroy -var-file=terraform.tfvars
```
