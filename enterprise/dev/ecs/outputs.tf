output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "capacity_provider_name" {
  description = "Name of the ECS Managed Instances capacity provider"
  value       = aws_ecs_capacity_provider.managed.name
}

output "ip_service_name" {
  description = "Name of the awsvpc service registered in the IP target group"
  value       = aws_ecs_service.ip.name
}

output "instance_service_name" {
  description = "Name of the bridge service registered in the instance target group"
  value       = aws_ecs_service.instance.name
}
