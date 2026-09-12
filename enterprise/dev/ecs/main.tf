provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  env                  = basename(dirname(abspath(path.module)))
  vpc_config           = local.common.environments[local.env].vpc
  region               = local.common.region
  name                 = "${local.vpc_config.name}-${local.env}-ecs"
  vpc_name             = "${local.vpc_config.name}-${local.env}"
  private_subnet_names = var.private_subnet_names != null ? var.private_subnet_names : [for suffix in ["1a", "1b"] : "app-${local.vpc_name}-snet-${suffix}"]
  private_subnet_ids   = [for name in local.private_subnet_names : data.aws_subnet.private[name].id]
  target_group_prefix  = var.alb_type == "external" ? "${local.vpc_config.name}-${local.env}-ext" : "${local.vpc_config.name}-${local.env}-int"
  tags                 = merge(local.common.tags, { Environment = local.env })
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

data "aws_lb_target_group" "ip" {
  name = "${local.target_group_prefix}-ip"
}

data "aws_lb_target_group" "instance" {
  name = "${local.target_group_prefix}-ec2"
}

module "managed_instance_role" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name                    = "ecsInstanceRole-${local.vpc_config.name}-${local.env}"
  use_name_prefix         = false
  create_instance_profile = true

  trust_policy_permissions = {
    EC2AssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonECSInstanceRolePolicyForManagedInstances = "arn:aws:iam::aws:policy/AmazonECSInstanceRolePolicyForManagedInstances"
    AmazonSSMManagedInstanceCore                   = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

module "managed_infrastructure_role" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name            = "${local.name}-infrastructure"
  use_name_prefix = false

  trust_policy_permissions = {
    ECSAssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ecs.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonECSInfrastructureRolePolicyForManagedInstances = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForManagedInstances"
  }

  tags = local.tags
}

module "task_execution_role" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name            = "${local.name}-task-execution"
  use_name_prefix = false

  trust_policy_permissions = {
    ECSTasksAssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonECSTaskExecutionRolePolicy = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${local.name}"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = local.tags
}

resource "aws_ecs_capacity_provider" "managed" {
  name    = "${local.name}-managed"
  cluster = aws_ecs_cluster.this.name

  managed_instances_provider {
    infrastructure_role_arn = module.managed_infrastructure_role.arn
    propagate_tags          = "CAPACITY_PROVIDER"

    instance_launch_template {
      ec2_instance_profile_arn = module.managed_instance_role.instance_profile_arn
      monitoring               = "DETAILED"

      network_configuration {
        subnets         = local.private_subnet_ids
        security_groups = [data.aws_security_group.app.id]
      }

      storage_configuration {
        storage_size_gib = var.storage_size_gib
      }

      instance_requirements {
        memory_mib {
          min = var.minimum_memory_mib
          max = var.maximum_memory_mib
        }

        vcpu_count {
          min = var.minimum_vcpu
          max = var.maximum_vcpu
        }

        instance_generations = ["current"]
        cpu_manufacturers    = ["intel", "amd"]
      }
    }
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.managed.name]

  default_capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.managed.name
    weight            = 1
  }

  lifecycle {
    replace_triggered_by = [aws_ecs_capacity_provider.managed]
  }
}

resource "aws_ecs_task_definition" "ip" {
  family                   = "${local.name}-ip"
  requires_compatibilities = ["MANAGED_INSTANCES"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = module.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app-ip"
      image     = var.container_image
      essential = true
      portMappings = [{
        name          = "app-ip"
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "ip"
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = local.tags
}

resource "aws_ecs_task_definition" "instance" {
  family                   = "${local.name}-instance"
  requires_compatibilities = ["MANAGED_INSTANCES"]
  network_mode             = "host"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = module.task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app-instance"
      image     = var.container_image
      essential = true
      portMappings = [{
        name          = "app-instance"
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "instance"
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = local.tags
}

resource "aws_ecs_service" "ip" {
  name                               = "${local.name}-ip"
  cluster                            = aws_ecs_cluster.this.arn
  task_definition                    = aws_ecs_task_definition.ip.arn
  desired_count                      = var.ip_service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  health_check_grace_period_seconds  = 60
  wait_for_steady_state              = false

  capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.managed.name
    weight            = 1
  }

  network_configuration {
    assign_public_ip = false
    security_groups  = [data.aws_security_group.app.id]
    subnets          = local.private_subnet_ids
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.ip.arn
    container_name   = "app-ip"
    container_port   = var.container_port
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]

  tags = local.tags
}

resource "aws_ecs_service" "instance" {
  name                               = "${local.name}-instance"
  cluster                            = aws_ecs_cluster.this.arn
  task_definition                    = aws_ecs_task_definition.instance.arn
  desired_count                      = var.instance_service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  health_check_grace_period_seconds  = 60
  wait_for_steady_state              = false

  capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.managed.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.instance.arn
    container_name   = "app-instance"
    container_port   = var.container_port
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]

  tags = local.tags
}
