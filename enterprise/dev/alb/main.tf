provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  default_environment  = basename(dirname(abspath(path.module)))
  environment          = coalesce(var.env, local.default_environment)
  vpc_config           = local.common.environments[local.environment].vpc
  region               = coalesce(var.region, local.common.region)
  workload_name        = coalesce(var.name, "enterprise")
  vpc_name             = coalesce(var.vpc_name, "${local.vpc_config.name}-${local.environment}")
  public_subnet_names  = var.public_subnet_names != null ? var.public_subnet_names : [for suffix in ["1a", "1b"] : "lb-${local.vpc_name}-snet-${suffix}"]
  private_subnet_names = var.private_subnet_names != null ? var.private_subnet_names : [for suffix in ["1a", "1b"] : "app-${local.vpc_name}-snet-${suffix}"]

  name = "${local.workload_name}-${local.environment}"
  tags = merge(local.common.tags, {
    Environment = local.environment
  }, var.tags)

  https_enabled          = var.enable_https && var.certificate_arn != ""
  internal_https_enabled = var.enable_internal_https && var.certificate_arn != ""

  vpc_id                   = data.aws_vpc.this.id
  vpc_cidr                 = data.aws_vpc.this.cidr_block
  public_subnet_ids        = [for name in local.public_subnet_names : data.aws_subnet.public[name].id]
  private_subnet_ids       = [for name in local.private_subnet_names : data.aws_subnet.private[name].id]
  default_target_group_key = var.default_target_group_type

  additional_attachments = {
    for idx, id in var.target_ids : "target-${idx}" => {
      target_group_key = "instance"
      target_id        = id
      port             = var.target_port
    }
  }

  http_listener_external = var.enable_http ? (
    local.https_enabled ? {
      http = {
        port     = 80
        protocol = "HTTP"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }
      } : {
      http = {
        port     = 80
        protocol = "HTTP"
        forward = {
          target_group_key = local.default_target_group_key
        }
      }
    }
  ) : {}

  https_listener_external = local.https_enabled ? {
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = var.ssl_policy
      certificate_arn = var.certificate_arn
      forward = {
        target_group_key = local.default_target_group_key
      }
    }
  } : {}

  http_listener_internal = var.enable_http ? {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = local.default_target_group_key
      }
    }
  } : {}

  https_listener_internal = local.internal_https_enabled ? {
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = var.ssl_policy
      certificate_arn = var.certificate_arn
      forward = {
        target_group_key = local.default_target_group_key
      }
    }
  } : {}
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]
  }
}

data "aws_subnet" "public" {
  for_each = toset(local.public_subnet_names)

  filter {
    name   = "tag:Name"
    values = [each.value]
  }

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
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
    values = [local.vpc_id]
  }
}

################################################################################
# Internet-facing ALB (external) — HTTP and/or HTTPS
################################################################################

module "alb_external" {
  source = "../../../modules/v1/terraform-aws-alb"

  create = var.create_external_alb

  name                       = "${local.name}-ext"
  load_balancer_type         = "application"
  vpc_id                     = local.vpc_id
  subnets                    = local.public_subnet_ids
  internal                   = false
  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = var.enable_http2
  idle_timeout               = var.idle_timeout
  drop_invalid_header_fields = var.drop_invalid_header_fields
  access_logs                = var.access_logs

  security_group_ingress_rules = merge(
    var.enable_http ? {
      http = {
        from_port   = 80
        to_port     = 80
        ip_protocol = "tcp"
        description = "HTTP"
        cidr_ipv4   = "0.0.0.0/0"
      }
    } : {},
    local.https_enabled ? {
      https = {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        description = "HTTPS"
        cidr_ipv4   = "0.0.0.0/0"
      }
    } : {}
  )

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = merge(local.http_listener_external, local.https_listener_external)

  target_groups = {
    ip = {
      name        = "${local.name}-ext-ip"
      protocol    = "HTTP"
      port        = var.target_port
      target_type = "ip"
      vpc_id      = local.vpc_id

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      protocol_version  = "HTTP1"
      create_attachment = false
    }
    instance = {
      name        = "${local.name}-ext-ec2"
      protocol    = "HTTP"
      port        = var.target_port
      target_type = "instance"
      vpc_id      = local.vpc_id

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      protocol_version  = "HTTP1"
      create_attachment = false
    }
  }

  additional_target_group_attachments = local.additional_attachments

  tags = merge(local.tags, {
    Scheme = "internet-facing"
  })
}

################################################################################
# Internal ALB — private subnets, HTTP by default, optional HTTPS
################################################################################

module "alb_internal" {
  source = "../../../modules/v1/terraform-aws-alb"

  create = var.create_internal_alb

  name                       = "${local.name}-int"
  load_balancer_type         = "application"
  vpc_id                     = local.vpc_id
  subnets                    = local.private_subnet_ids
  internal                   = true
  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = var.enable_http2
  idle_timeout               = var.idle_timeout
  drop_invalid_header_fields = var.drop_invalid_header_fields
  access_logs                = var.access_logs

  security_group_ingress_rules = merge(
    var.enable_http ? {
      http = {
        from_port   = 80
        to_port     = 80
        ip_protocol = "tcp"
        description = "HTTP from VPC"
        cidr_ipv4   = local.vpc_cidr
      }
    } : {},
    local.internal_https_enabled ? {
      https = {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        description = "HTTPS from VPC"
        cidr_ipv4   = local.vpc_cidr
      }
    } : {}
  )

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = merge(local.http_listener_internal, local.https_listener_internal)

  target_groups = {
    ip = {
      name        = "${local.name}-int-ip"
      protocol    = "HTTP"
      port        = var.target_port
      target_type = "ip"
      vpc_id      = local.vpc_id

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      create_attachment = false
    }
    instance = {
      name        = "${local.name}-int-ec2"
      protocol    = "HTTP"
      port        = var.target_port
      target_type = "instance"
      vpc_id      = local.vpc_id

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-399"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      create_attachment = false
    }
  }

  additional_target_group_attachments = local.additional_attachments

  tags = merge(local.tags, {
    Scheme = "internal"
  })
}
