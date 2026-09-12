provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  common = jsondecode(file("${path.module}/../../common/config.json"))

  env         = basename(dirname(abspath(path.module)))
  region      = local.common.region
  bucket_name = "${local.common.account_name}-${local.env}-audit-${data.aws_caller_identity.current.account_id}"
  bucket_arn  = "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}"
  trail_name  = "${local.common.account_name}-${local.env}-trail"
  trail_arn   = "arn:${data.aws_partition.current.partition}:cloudtrail:${local.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
  log_prefix  = "cloudtrail"
  tags        = merge(local.common.tags, { Environment = local.env })
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = [
      local.bucket_arn,
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${local.bucket_arn}/${local.log_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

module "audit_bucket" {
  source = "../../../modules/v1/terraform-aws-s3-bucket"

  bucket        = local.bucket_name
  force_destroy = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  attach_policy = true
  policy        = data.aws_iam_policy_document.cloudtrail_bucket.json

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {}

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(local.tags, { Name = local.bucket_name })
}

resource "aws_cloudtrail" "this" {
  name                          = local.trail_name
  s3_bucket_name                = module.audit_bucket.s3_bucket_id
  s3_key_prefix                 = local.log_prefix
  enable_logging                = true
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = true

  event_selector {
    include_management_events = true
    read_write_type           = "All"

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${local.bucket_arn}/"]
    }
  }

  depends_on = [module.audit_bucket]

  tags = local.tags
}
