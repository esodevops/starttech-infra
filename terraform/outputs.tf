# -------------------------------------------------
# Root Terraform - Outputs
# These print the important URLs/names after deploy
# -------------------------------------------------

output "frontend_url" {
  description = "CloudFront URL — open this in a browser to see the React app"
  value       = "https://${module.storage.cloudfront_domain_name}"
}

output "backend_url" {
  description = "ALB URL — the backend API is accessible here"
  value       = "http://${module.compute.alb_dns_name}"
}

output "frontend_bucket_name" {
  description = "S3 bucket name — upload React build files here"
  value       = module.storage.frontend_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used for cache invalidation after deploy"
  value       = module.storage.cloudfront_distribution_id
}

output "autoscaling_group_name" {
  description = "ASG name — used for rolling deployments"
  value       = module.compute.autoscaling_group_name
}

output "backend_log_group" {
  description = "CloudWatch log group where backend logs appear"
  value       = module.monitoring.backend_log_group_name
}
