# -------------------------------------------------
# Monitoring Module - Input Variables
# -------------------------------------------------

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "log_retention_days" {
  description = "How many days to keep logs in CloudWatch"
  type        = number
  default     = 30
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics (provided by the compute module)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch metrics"
  type        = string
}

variable "alert_email" {
  description = "Email address to send CloudWatch alarm notifications to"
  type        = string
}
