variable "vpc_name" {
  description = "Value of the Name tag on the VPC"
  type        = string
}

variable "subnet_names" {
  description = "Map of logical names to subnet Name tags"
  type        = map(string)
  default     = {}
}

variable "security_group_names" {
  description = "Map of logical names to security group names"
  type        = map(string)
  default     = {}
}
