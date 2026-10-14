output "bucket_name" {
  description = "Name of the private encrypted audit bucket"
  value       = module.audit_bucket.s3_bucket_id
}

output "bucket_arn" {
  description = "ARN of the private encrypted audit bucket"
  value       = module.audit_bucket.s3_bucket_arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.this.arn
}
