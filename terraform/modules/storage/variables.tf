# -------------------------------------------------
# Storage Module - Input Variables
# -------------------------------------------------

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "frontend_bucket_name" {
  description = "Globally unique S3 bucket name for the React frontend"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ElastiCache (needs 2+ subnets in different AZs)"
  type        = list(string)
}

variable "redis_security_group_id" {
  description = "Security group ID for Redis"
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

variable "alb_dns_name" {
  description = "ALB DNS name for CloudFront API proxy origin (empty string disables proxy)"
  type        = string
  default     = ""
}
