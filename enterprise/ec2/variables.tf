variable "vpc_name" {
  description = "Name tag of the VPC created by enterprise/vpc-prod"
  type        = string
  default     = "wynk-prod"
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
