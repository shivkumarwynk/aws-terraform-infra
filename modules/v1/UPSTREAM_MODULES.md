# Vendored upstream modules

The following modules are copied from the official
[`terraform-aws-modules`](https://github.com/terraform-aws-modules)
organization:

| Local path | Upstream repository | Release |
|---|---|---|
| `terraform-aws-iam` | `terraform-aws-modules/terraform-aws-iam` | `v6.8.1` |
| `terraform-aws-security-group` | `terraform-aws-modules/terraform-aws-security-group` | `v6.0.0` |

Keep release upgrades isolated and validate every consuming root because major
versions can change resource addresses and input schemas.
