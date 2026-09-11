provider "aws" {
  region = local.common.region
}

locals {
  common          = jsondecode(file("${path.module}/../../common/config.json"))
  environment     = "non-production"
  repository_name = "wynknon-production"
}

#module "s3_bucket_for_logs" {
#  source = "../../../modules/v1/terraform-aws-s3-bucket"

#  bucket = "my-s3qdw3e-bucket-for-logs"

# Allow deletion of non-empty bucket
# force_destroy = true

# control_object_ownership = true
# object_ownership         = "ObjectWriter"

#  attach_elb_log_delivery_policy = true  # Required for ALB logs
#  attach_lb_log_delivery_policy  = true  # Required for ALB/NLB logs
#}
#####################
#module "s3_bucket" {
#  source = "../../../modules/v1/terraform-aws-s3-bucket"

#  bucket = "my-s3asqwdwe-bucket"
#  acl    = "private"

#  control_object_ownership = true
#  object_ownership         = "ObjectWriter"

#  versioning = {
#    enabled = true
#  }
#}


module "ecr" {
  source = "../../../modules/v1/terraform-aws-ecr"

  repository_name = local.repository_name
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 60 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["staging"],
          countType     = "imageCountMoreThan",
          countNumber   = 60
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = merge(local.common.tags, {
    Environment = local.environment
  })
}
