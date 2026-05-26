# -------------------------------------------------
# Root Terraform - Main Configuration
# This file wires together all four modules:
#   1. networking  → VPC, subnets, security groups
#   2. storage     → S3, CloudFront, Redis
#   3. monitoring  → CloudWatch log groups & alarms
#   4. compute     → ALB, EC2 ASG (created last because
#                    it needs Redis endpoint and log group name)
# -------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Store Terraform state in S3 so the whole team shares the same state.
  # Create this bucket manually once before running `terraform init`.
  backend "s3" {
    bucket = "starttech-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ---- Module 1: Networking ----
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  availability_zones   = var.availability_zones
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ---- Module 2: Storage (S3 + CloudFront + Redis) ----
module "storage" {
  source = "./modules/storage"

  project_name            = var.project_name
  environment             = var.environment
  frontend_bucket_name    = var.frontend_bucket_name
  private_subnet_ids      = module.networking.private_subnet_ids
  redis_security_group_id = module.networking.redis_security_group_id
  alb_dns_name            = var.alb_dns_name
}

# ---- Module 3: Monitoring (CloudWatch Logs + Alarms) ----
# Created before compute so the log group name is available for user_data
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email

  # These come from the compute module output — pass dummy values during first apply
  # Terraform will update them on the second apply once the ALB exists.
  alb_arn_suffix          = try(module.compute.alb_arn, "")
  target_group_arn_suffix = try(module.compute.target_group_arn, "")
}

# ---- Module 4: Compute (ALB + EC2 ASG) ----
module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  private_subnet_ids        = module.networking.private_subnet_ids
  alb_security_group_id     = module.networking.alb_security_group_id
  backend_security_group_id = module.networking.backend_security_group_id

  ami_id          = var.ami_id
  instance_type   = var.instance_type
  docker_image    = var.docker_image
  mongo_uri       = var.mongo_uri
  redis_endpoint  = module.storage.redis_endpoint
  allowed_origins = "http://localhost:5173,https://${module.storage.cloudfront_domain_name}"

  cloudwatch_log_group      = module.monitoring.backend_log_group_name
  aws_region                = var.aws_region
  iam_instance_profile_name = "${var.project_name}-ec2-profile"
}
