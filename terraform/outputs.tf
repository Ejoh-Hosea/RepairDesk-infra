output "nameservers" {
  description = "Paste these 4 values into GoDaddy nameservers — CRITICAL STEP"
  value       = aws_route53_zone.main.name_servers
}

output "frontend_url" {
  value = "https://${var.domain_name}"
}

output "api_url" {
  value = "https://${var.api_subdomain}.${var.domain_name}"
}

output "ecr_repository_url" {
  description = "GitHub Actions pushes Docker images here"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "ecs_task_family" {
  value = "${var.project}-task"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "github_actions_access_key_id" {
  description = "Add to GitHub Secrets as AWS_ACCESS_KEY_ID"
  value       = aws_iam_access_key.github_actions.id
}

output "github_actions_secret_access_key" {
  description = "Add to GitHub Secrets as AWS_SECRET_ACCESS_KEY"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}
