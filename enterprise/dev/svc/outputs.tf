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
      container_name = local.services[name].task_definition.container_definitions[0].name
      container_port = local.services[name].target_group.port
    }
  }
}
