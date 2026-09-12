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

module "instance_service_role" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name                 = "${local.name}-instance-service"
  use_name_prefix      = false
  create_inline_policy = true

  trust_policy_permissions = {
    ECSAssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ecs.amazonaws.com"]
      }]
    }
  }

  inline_policy_permissions = {
    LoadBalancerRegistration = {
      actions = [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets",
      ]
      resources = ["*"]
    }
  }

  tags = local.tags
}



resource "aws_ecs_cluster" "ecs" {
  name = local.name

  setting {
    name  = "containerInsights"
    #value = "enhanced"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_capacity_provider" "managed" {
  name    = "${local.name}-managed"
  cluster = aws_ecs_cluster.ecs.name

  managed_instances_provider {
    infrastructure_role_arn = module.managed_infrastructure_role.arn
    propagate_tags          = "CAPACITY_PROVIDER"

    instance_launch_template {
      ec2_instance_profile_arn = module.managed_instance_role.instance_profile_arn
      monitoring               = "BASIC" #DETAILED

      network_configuration {
        subnets         = local.private_subnet_ids
        security_groups = [data.aws_security_group.app.id]
      }

      storage_configuration {
        storage_size_gib = var.storage_size_gib
      }
      infrastructure_optimization {
       scale_in_after = "180"
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
        cpu_manufacturers    = ["amd"] #intel
      }
    }
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "cluster_capacity_providers" {
  cluster_name       = aws_ecs_cluster.ecs.name
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
