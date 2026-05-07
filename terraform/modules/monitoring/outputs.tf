# -------------------------------------------------
# Monitoring Module - Outputs
# -------------------------------------------------

output "backend_log_group_name" {
  description = "CloudWatch log group name for backend logs"
  value       = aws_cloudwatch_log_group.backend.name
}

output "alerts_sns_topic_arn" {
  description = "SNS topic ARN for alert notifications"
  value       = aws_sns_topic.alerts.arn
}
