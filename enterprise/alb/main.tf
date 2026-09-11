provider "aws" {
  region = var.region
}

locals {
  name = "${var.name}-${var.env}"
  tags = merge({
    Name        = local.name
    Environment = var.env
    Terraform   = "true"
  }, var.tags)

  https_enabled          = var.enable_https && var.certificate_arn != ""
  internal_https_enabled = var.enable_internal_https && var.certificate_arn != ""

  vpc                = var.vpc_id == null ? data.aws_vpc.lookup[0] : data.aws_vpc.by_id[0]
  vpc_id             = local.vpc.id
  vpc_cidr           = local.vpc.cidr_block
  public_subnet_ids  = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.public[0].ids
  private_subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.aws_subnets.private[0].ids

  additional_attachments = {
    for idx, id in var.target_ids : "target-${idx}" => {
      target_group_key = "app"
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
          target_group_key = "app"
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
        target_group_key = "app"
      }
    }
  } : {}

  http_listener_internal = var.enable_http ? {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "app"
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
        target_group_key = "app"
      }
    }
  } : {}
}

data "aws_vpc" "lookup" {
  count = var.vpc_id == null ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_vpc" "by_id" {
  count = var.vpc_id == null ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnets" "public" {
  count = length(var.public_subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = var.public_subnet_names
  }
}

data "aws_subnets" "private" {
  count = length(var.private_subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = var.private_subnet_names
  }
}

################################################################################
# Internet-facing ALB (external) — HTTP and/or HTTPS
################################################################################

module "alb_external" {
  source = "../../modules/v1/terraform-aws-alb"

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
    app = {
      name_prefix = "appex"
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
  source = "../../modules/v1/terraform-aws-alb"

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
    app = {
      name_prefix = "appin"
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
