output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

output "capacity_provider_name" {
  description = "Name of the EC2 Auto Scaling capacity provider"
  value       = module.ecs_cluster.autoscaling_capacity_providers["ec2"].name
}

output "autoscaling_group_name" {
  description = "Name of the ECS capacity Auto Scaling group"
  value       = aws_autoscaling_group.ecs.name
}
