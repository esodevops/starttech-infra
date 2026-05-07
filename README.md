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
