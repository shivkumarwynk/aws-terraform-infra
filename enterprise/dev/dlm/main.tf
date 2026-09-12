resource "aws_iam_role" "dlm" {
  name = "${local.name}-${local.env}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "dlm.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "dlm" {
  name = "${local.name}-${local.env}-dlm-policy"
  role = aws_iam_role.dlm.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags"
        ]

        Resource = "*"
      }
    ]
  })
}
resource "aws_dlm_lifecycle_policy" "ebs" {
  description        = "${local.name}-${local.env} EBS snapshot policy"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Snapshot = "true"
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

  tags = local.common_tags
}
