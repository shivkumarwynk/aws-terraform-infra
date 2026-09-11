output "ec2_role_arn" {
  description = "ARN of the enterprise EC2 IAM role"
  value       = module.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the enterprise EC2 instance profile"
  value       = module.ec2_role.instance_profile_name
}
