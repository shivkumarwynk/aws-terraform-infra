provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  env                  = basename(dirname(abspath(path.module)))
  region               = local.common.region
  vpc_config           = local.common.environments[local.env].vpc
  vpc_name             = "${local.vpc_config.name}-${local.env}"
  cluster_name         = "${local.vpc_name}-ecs"
  capacity_provider    = "${local.cluster_name}-managed"
  private_subnet_names = [for suffix in ["1a", "1b"] : "app-${local.vpc_name}-snet-${suffix}"]
  private_subnet_ids   = [for name in local.private_subnet_names : data.aws_subnet.private[name].id]
  service_files        = fileset(path.module, "svc/*.json")
  services = {
    for file in local.service_files :
    trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/${file}"))
  }
  tags = merge(local.common.tags, { Environment = local.env })
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]
  }
}

data "aws_subnet" "private" {
  for_each = toset(local.private_subnet_names)

  filter {
    name   = "tag:Name"
    values = [each.value]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

data "aws_security_group" "app" {
  filter {
    name   = "group-name"
    values = ["${local.vpc_name}-app"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

data "aws_ecs_cluster" "this" {
  cluster_name = local.cluster_name
}

data "aws_iam_role" "task_execution" {
  name = "${local.cluster_name}-task-execution"
}

resource "aws_iam_role_policy" "create_log_groups" {
  name = "${local.cluster_name}-create-log-groups"
  role = data.aws_iam_role.task_execution.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CreateServiceLogGroups"
      Effect = "Allow"
      Action = ["logs:CreateLogGroup"]
      Resource = distinct(flatten([
        for service in values(local.services) : [
          for container in service.containerDefinitions :
          "arn:${data.aws_partition.current.partition}:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:${container.logConfiguration.options["awslogs-group"]}"
          if try(container.logConfiguration.logDriver, "") == "awslogs"
        ]
      ]))
    }]
  })
}

resource "aws_ecs_task_definition" "service" {
  for_each = local.services

  family                   = each.value.family
  requires_compatibilities = each.value.requiresCompatibilities
  network_mode             = each.value.networkMode
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = each.value.executionRoleArn
  task_role_arn            = each.value.taskRoleArn

  container_definitions = jsonencode([
    for container in each.value.containerDefinitions :
    merge(container, {
      logConfiguration = merge(container.logConfiguration, {
        options = merge(container.logConfiguration.options, {
          awslogs-create-group = "true"
        })
      })
    })
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = merge(local.tags, {
    Name    = "${local.cluster_name}-${each.key}"
    Service = each.key
  })
}

resource "aws_lb_target_group" "service" {
  for_each = local.services

  name        = substr("${local.vpc_name}-${each.key}", 0, 32)
  port        = each.value.containerDefinitions[0].portMappings[0].containerPort
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.this.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, {
    Name    = "${local.vpc_name}-${each.key}"
    Service = each.key
  })
}

resource "aws_ecs_service" "service" {
  for_each = local.services

  name                   = each.key
  cluster                = data.aws_ecs_cluster.this.arn
  task_definition        = aws_ecs_task_definition.service[each.key].arn
  desired_count          = 1
  enable_execute_command = true

  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  capacity_provider_strategy {
    capacity_provider = local.capacity_provider
    base              = 1
    weight            = 1
  }

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [data.aws_security_group.app.id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # Preserve target groups added manually after their ALB listener rules exist.
    ignore_changes = [load_balancer]
  }

  tags = merge(local.tags, {
    Name    = "${local.cluster_name}-${each.key}"
    Service = each.key
  })
}
