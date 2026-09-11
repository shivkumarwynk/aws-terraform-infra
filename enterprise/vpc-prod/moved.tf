# Preserve existing security group identities while moving ownership from raw
# resources to terraform-aws-modules/terraform-aws-security-group.
moved {
  from = aws_security_group.rds
  to   = module.security_groups["rds"].aws_security_group.this[0]
}

moved {
  from = aws_security_group.db
  to   = module.security_groups["db"].aws_security_group.this[0]
}

moved {
  from = aws_security_group.alb
  to   = module.security_groups["alb"].aws_security_group.this[0]
}

moved {
  from = aws_security_group.app
  to   = module.security_groups["app"].aws_security_group.this[0]
}

moved {
  from = aws_security_group.vpn
  to   = module.security_groups["vpn"].aws_security_group.this[0]
}
