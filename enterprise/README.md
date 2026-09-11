# Enterprise environments

Each folder is a complete Terraform root with an independent S3 state:

| Folder | VPC CIDR | State key |
|---|---|---|
| `prod` | `10.14.0.0/16` | `enterprise/prod/terraform.tfstate` |
| `staging` | `10.15.0.0/16` | `enterprise/staging/terraform.tfstate` |
| `dev` | `10.16.0.0/16` | `enterprise/dev/terraform.tfstate` |

All three roots call `modules/v1/terraform-aws-enterprise-environment`, which
creates the VPC, subnets, security groups, EC2 IAM profile, configured EC2
instances, internal/external ALBs, and ECR repository in dependency order.

Set these GitHub Actions values:

- Repository secrets: `ENTERPRISE_AWS_ACCESS_KEY_ID`,
  `ENTERPRISE_AWS_SECRET_ACCESS_KEY`
- Repository variable: `ENTERPRISE_AWS_REGION` (optional; defaults to
  `ap-south-1`)
- Repository variable: `ENTERPRISE_TF_STATE_BUCKET` (required for plan/apply)

The state bucket must already exist. State locking uses the S3 lockfile, so a
DynamoDB table is not required.

## Migration warning

This replaces the previous component-level roots (`vpc-prod`, `iam`, `ec2`,
`alb`, and `s3`) with environment-level roots. If those old roots were already
applied, migrate/import their state before applying the new roots. Do not apply
the new production root over existing resources without reviewing and
completing that state migration.
