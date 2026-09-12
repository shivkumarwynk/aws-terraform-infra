provider "aws" {
  region = local.region
}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  env         = basename(dirname(abspath(path.module)))
  name        = local.common.environments[local.env].vpc.name
  region      = local.common.region
  common_tags = merge(local.common.tags, { Environment = local.env })
}

module "dlm_role" {
  source = "../../../modules/v1/terraform-aws-iam/modules/iam-role"

  name            = "${local.name}-${local.env}-dlm"
  use_name_prefix = false

  trust_policy_permissions = {
    DLMAssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["dlm.amazonaws.com"]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    ManageSnapshots = {
      actions = [
        "ec2:CreateSnapshot",
        "ec2:CreateSnapshots",
        "ec2:CreateTags",
        "ec2:DeleteSnapshot",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
      ]
      resources = ["*"]
    }
  }

  tags = local.common_tags
}

resource "aws_dlm_lifecycle_policy" "ebs" {
  description        = "${local.name}-${local.env} EBS snapshot policy"
  execution_role_arn = module.dlm_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Environment = local.env
    }

    schedule {
      name = "Daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        SnapshotType = "DLM"
        Environment  = local.env
      }

      copy_tags = true
    }
  }
  tags = merge(local.common_tags, {
    Name = "${local.name}-${local.env}-ebs-dlm"
  })
}
