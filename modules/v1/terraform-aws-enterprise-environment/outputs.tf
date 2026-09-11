output "vpc_id" {
  description = "Environment VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Environment public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Environment private subnet IDs"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "Environment database subnet IDs"
  value       = module.vpc.database_subnets
}

output "security_group_ids" {
  description = "Environment security group IDs"
  value       = { for key, security_group in module.security_groups : key => security_group.id }
}

output "ec2_instance_ids" {
  description = "Environment EC2 instance IDs"
  value       = { for key, instance in module.ec2_instances : key => instance.id }
}

output "ec2_instance_profile_name" {
  description = "Environment EC2 instance profile name"
  value       = module.ec2_role.instance_profile_name
}

output "external_alb_dns_name" {
  description = "External ALB DNS name"
  value       = module.alb_external.dns_name
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name"
  value       = module.alb_internal.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}
