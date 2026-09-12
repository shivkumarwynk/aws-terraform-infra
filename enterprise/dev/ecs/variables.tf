variable "instance_type" {
  description = "EC2 instance type used by the ECS capacity provider"
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "Minimum number of ECS container instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of ECS container instances"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Initial desired number of ECS container instances"
  type        = number
  default     = 1
}

variable "root_volume_size" {
  description = "Encrypted root EBS volume size in GiB"
  type        = number
  default     = 30
}

variable "private_subnet_names" {
  description = "Optional private subnet Name tag overrides"
  type        = list(string)
  default     = null
}
