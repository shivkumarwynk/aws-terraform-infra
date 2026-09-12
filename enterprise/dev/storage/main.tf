locals {
  bucket_names = [
    "backup",
    "application"
  ]
}

module "storage_buckets" {
  for_each = toset(local.bucket_names)

  source = "../../../modules/v1/terraform-aws-s3-bucket"

  bucket        = "${local.name}-${local.env}-${each.key}"
  force_destroy = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  attach_policy = each.key == "audit"
  policy        = each.key == "audit" ? data.aws_iam_policy_document.cloudtrail_bucket.json : null

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

  tags = merge(local.tags, {
    Name = "${local.name}-${local.env}-${each.key}"
  })
}
