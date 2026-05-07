# -------------------------------------------------
# Root Terraform - Variables
# -------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name used as a prefix for all resources"
  type        = string
  default     = "starttech"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ---- Networking ----
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use (must match your region)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ---- Compute ----
variable "ami_id" {
  description = "Amazon Linux 2 AMI ID (find latest at https://aws.amazon.com/amazon-linux-2/)"
  type        = string
  # Example for us-east-1: ami-0c02fb55956c7d316
}

variable "instance_type" {
  description = "EC2 instance type for backend servers"
  type        = string
  default     = "t3.micro"
}

variable "docker_image" {
  description = "Backend Docker image (e.g. dockerhub-user/much-to-do-backend:latest)"
  type        = string
}

variable "mongo_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true # will not be printed in Terraform output
}

# ---- Storage ----
variable "frontend_bucket_name" {
  description = "S3 bucket name for React app (must be globally unique)"
  type        = string
}

# ---- Monitoring ----
variable "alert_email" {
  description = "Email to receive CloudWatch alarm notifications"
  type        = string
}
