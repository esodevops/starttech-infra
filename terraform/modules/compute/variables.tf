# -------------------------------------------------
# Compute Module - Input Variables
# -------------------------------------------------

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for backend EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2)"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "desired_instances" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

variable "docker_image" {
  description = "Docker image for the backend (e.g. your-dockerhub/app:latest)"
  type        = string
}

variable "mongo_uri" {
  description = "MongoDB Atlas connection string (stored as a secret)"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "Redis ElastiCache endpoint"
  type        = string
}

variable "allowed_origins" {
  description = "Comma-separated list of allowed CORS origins for the backend"
  type        = string
  default     = "http://localhost:5173"
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group name for backend logs"
  type        = string
}

variable "aws_region" {
  description = "AWS region used by Docker awslogs log driver"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile to attach to EC2 instances"
  type        = string
}
