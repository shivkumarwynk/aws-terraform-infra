data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  services = jsondecode(file("${path.module}/svc/services.json"))

  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.${data.aws_partition.current.dns_suffix}"
}

resource "aws_cloudwatch_log_group" "service" {
  for_each = local.services

  name              = "/aws/ecs/${local.name}/${each.key}"
  retention_in_days = 30

  tags = merge(local.tags, {
    Name    = "/aws/ecs/${local.name}/${each.key}"
    Service = each.key
  })
}

resource "aws_ecs_task_definition" "service" {
  for_each = local.services

  family                   = "${local.name}-${each.key}"
  requires_compatibilities = ["MANAGED_INSTANCES"]
  network_mode             = "awsvpc"
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = module.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${local.ecr_registry}/${each.value.repository}:${each.value.image_tag}"
      essential = true
      cpu       = each.value.cpu
      memory    = each.value.memory

      portMappings = [
        {
          name          = "${each.key}-http"
          containerPort = each.value.container_port
          hostPort      = each.value.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service[each.key].name
          awslogs-region        = local.region
          awslogs-stream-prefix = each.key
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = merge(local.tags, {
    Name    = "${local.name}-${each.key}"
    Service = each.key
  })
}

resource "aws_lb_target_group" "service" {
  for_each = local.services

  name        = "${local.vpc_config.name}-${local.env}-${each.key}"
  port        = each.value.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.this.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = each.value.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(local.tags, {
    Name    = "${local.vpc_config.name}-${local.env}-${each.key}"
    Service = each.key
  })
}

resource "aws_ecs_service" "service" {
  for_each = local.services

  name            = each.key
  cluster         = aws_ecs_cluster.ecs.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = each.value.desired_count

  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.managed.name
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
    # Target groups are associated manually after they are attached to ALB listeners.
    ignore_changes = [load_balancer]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.cluster_capacity_providers]

  tags = merge(local.tags, {
    Name    = "${local.name}-${each.key}"
    Service = each.key
  })
}
