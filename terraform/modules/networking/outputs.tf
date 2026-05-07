# -------------------------------------------------
# Networking Module - Outputs
# These values are passed to other modules
# -------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (used by ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (used by EC2 and ElastiCache)"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "backend_security_group_id" {
  description = "Security group ID for backend EC2 instances"
  value       = aws_security_group.backend.id
}

output "redis_security_group_id" {
  description = "Security group ID for ElastiCache Redis"
  value       = aws_security_group.redis.id
}
