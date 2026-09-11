variable "vpc_name" {
  description = "Optional VPC Name tag override; defaults to enterprise/common/config.json"
  type        = string
  default     = null
}

variable "subnet_names" {
  description = "Optional overrides of logical EC2 role to subnet Name tag"
  type        = map(string)
  default     = {}
}

variable "security_group_names" {
  description = "Optional overrides of logical EC2 role to security group name"
  type        = map(string)
  default     = {}
}
