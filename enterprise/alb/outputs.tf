output "external_alb_id" {
  description = "Internet-facing ALB ID"
  value       = module.alb_external.id
}

output "external_alb_arn" {
  description = "Internet-facing ALB ARN"
  value       = module.alb_external.arn
}

output "external_alb_dns_name" {
  description = "Internet-facing ALB DNS name"
  value       = module.alb_external.dns_name
}

output "external_alb_zone_id" {
  description = "Internet-facing ALB hosted zone ID"
  value       = module.alb_external.zone_id
}

output "external_alb_security_group_id" {
  description = "Internet-facing ALB security group ID"
  value       = module.alb_external.security_group_id
}

output "external_target_groups" {
  description = "Internet-facing ALB target groups"
  value       = module.alb_external.target_groups
}

output "internal_alb_id" {
  description = "Internal ALB ID"
  value       = module.alb_internal.id
}

output "internal_alb_arn" {
  description = "Internal ALB ARN"
  value       = module.alb_internal.arn
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name"
  value       = module.alb_internal.dns_name
}

output "internal_alb_zone_id" {
  description = "Internal ALB hosted zone ID"
  value       = module.alb_internal.zone_id
}

output "internal_alb_security_group_id" {
  description = "Internal ALB security group ID"
  value       = module.alb_internal.security_group_id
}

output "internal_target_groups" {
  description = "Internal ALB target groups"
  value       = module.alb_internal.target_groups
}
