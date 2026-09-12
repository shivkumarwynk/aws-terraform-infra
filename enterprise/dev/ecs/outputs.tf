output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.ecs.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.ecs.name
}

output "capacity_provider_name" {
  description = "Name of the ECS Managed Instances capacity provider"
  value       = aws_ecs_capacity_provider.managed.name
}
