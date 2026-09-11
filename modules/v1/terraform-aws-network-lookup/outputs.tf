output "vpc_id" {
  description = "Discovered VPC ID"
  value       = data.aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Discovered VPC CIDR block"
  value       = data.aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Map of logical subnet names to discovered subnet IDs"
  value       = { for key, subnet in data.aws_subnet.this : key => subnet.id }
}

output "security_group_ids" {
  description = "Map of logical security group names to discovered IDs"
  value       = { for key, security_group in data.aws_security_group.this : key => security_group.id }
}
