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

output "service_names" {
  description = "ECS service names keyed by service"
  value       = { for name, service in aws_ecs_service.service : name => service.name }
}

output "task_definition_arns" {
  description = "Task definition ARNs keyed by service"
  value       = { for name, task in aws_ecs_task_definition.service : name => task.arn }
}

output "service_target_groups" {
  description = "IP target groups to attach manually to ALB listeners and ECS services"
  value = {
    for name, target_group in aws_lb_target_group.service : name => {
      arn            = target_group.arn
      container_name = name
      container_port = local.services[name].container_port
    }
  }
}
