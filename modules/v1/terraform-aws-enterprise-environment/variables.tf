variable "account_name" {
  description = "Logical AWS account/folder name"
  type        = string
}

variable "environment" {
  description = "Environment name (prod, staging, or dev)"
  type        = string

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be prod, staging, or dev."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "config" {
  description = "Environment-specific configuration loaded from enterprise/common/config.json"
  type        = any
}

variable "tags" {
  description = "Tags applied to every supported resource"
  type        = map(string)
  default     = {}
}
