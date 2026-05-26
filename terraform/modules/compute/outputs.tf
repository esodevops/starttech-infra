# -------------------------------------------------
# Compute Module - Outputs
# -------------------------------------------------

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer for CloudWatch metrics"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group"
  value       = aws_lb_target_group.backend.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group for CloudWatch metrics"
  value       = aws_lb_target_group.backend.arn_suffix
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.backend.name
}

output "ec2_iam_role_name" {
  description = "Name of the IAM role attached to EC2 instances"
  value       = aws_iam_role.ec2_role.name
}

# Output the instance profile name for use in root module
output "ec2_iam_instance_profile_name" {
  description = "Name of the IAM instance profile attached to EC2 instances"
  value       = aws_iam_instance_profile.ec2_profile.name
}
