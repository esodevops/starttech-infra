# -------------------------------------------------
# Storage Module - Outputs
# -------------------------------------------------

output "frontend_bucket_name" {
  description = "Name of the S3 bucket for the React frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (used to invalidate cache after deploy)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name — visit this URL to see the frontend"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "redis_endpoint" {
  description = "Redis cluster endpoint (hostname without port)"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}
