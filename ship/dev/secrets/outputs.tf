output "aws_account_id" {
  description = "AWS account selected by the active credentials"
  value       = data.aws_caller_identity.current.account_id
}

output "service_secret_arns" {
  description = "Secrets Manager ARN keyed by ECS service"
  value       = { for name, secret in aws_secretsmanager_secret.service : name => secret.arn }
}

output "service_secret_names" {
  description = "Secrets Manager name keyed by ECS service"
  value       = { for name, secret in aws_secretsmanager_secret.service : name => secret.name }
}

output "required_secret_keys" {
  description = "JSON keys that operators must populate before starting each service"
  value       = { for name, config in local.service_secrets : name => config.keys }
}
