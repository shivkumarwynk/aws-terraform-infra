output "external_alb_dns_name" {
  description = "DNS name of the external ALB"
  value       = module.alb_external.dns_name
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = module.alb_internal.dns_name
}

output "external_target_group_arns" {
  description = "External ALB target group ARNs keyed by ip and instance"
  value       = { for key, target_group in module.alb_external.target_groups : key => target_group.arn }
}

output "internal_target_group_arns" {
  description = "Internal ALB target group ARNs keyed by ip and instance"
  value       = { for key, target_group in module.alb_internal.target_groups : key => target_group.arn }
}
