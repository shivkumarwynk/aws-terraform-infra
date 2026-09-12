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

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
}

module "ecs_instance_profile" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name                    = "${local.name}-instance"
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
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${local.name}-"
  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = var.instance_type
  user_data = base64encode(<<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_ENABLE_TASK_IAM_ROLE=true
    ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
    EOF
  EOT
  )

  iam_instance_profile {
    name = module.ecs_instance_profile.instance_profile_name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
    }
  }

  vpc_security_group_ids = [data.aws_security_group.app.id]

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.name}-capacity" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tags, { Name = "${local.name}-capacity" })
  }

  update_default_version = true

  tags = local.tags
}

resource "aws_autoscaling_group" "ecs" {
  name                      = "${local.name}-capacity"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "EC2"
  protect_from_scale_in     = true
  vpc_zone_identifier       = [for name in local.private_subnet_names : data.aws_subnet.private[name].id]
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(local.tags, {
      AmazonECSManaged = "true"
      Name             = "${local.name}-capacity"
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

module "ecs_cluster" {
  source = "../../../modules/v1/terraform-aws-ecs/modules/cluster"

  name = local.name

  default_capacity_provider_strategy = {
    ec2 = {
      base   = 1
      weight = 1
    }
  }

  autoscaling_capacity_providers = {
    ec2 = {
      auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
      managed_draining               = "ENABLED"
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 2
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 80
      }
    }
  }

  cloudwatch_log_group_retention_in_days = 30

  tags = local.tags
}
