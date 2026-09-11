variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "name" {
  description = "Name prefix for ALB resources"
  type        = string
  default     = "enterprise"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID. If null, the VPC is looked up by var.vpc_name"
  type        = string
  default     = null
}

variable "vpc_name" {
  description = "Name tag of the VPC when vpc_id is not set (matches enterprise/vpc-prod module name)"
  type        = string
  default     = "wynk-prod"
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB. Empty list looks up var.public_subnet_names"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the internal ALB. Empty list looks up var.private_subnet_names"
  type        = list(string)
  default     = []
}

variable "public_subnet_names" {
  description = "Name tags of public/LB subnets when public_subnet_ids is empty"
  type        = list(string)
  default     = ["lb-prod-subnet-1a", "lb-prod-subnet-1b"]
}

variable "private_subnet_names" {
  description = "Name tags of private/app subnets when private_subnet_ids is empty"
  type        = list(string)
  default     = ["app-prod-subnet-1a", "app-prod-subnet-1b"]
}

variable "create_external_alb" {
  description = "Create the internet-facing (external) ALB"
  type        = bool
  default     = true
}

variable "create_internal_alb" {
  description = "Create the internal ALB"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Attach an HTTPS listener on the external ALB (requires certificate_arn)"
  type        = bool
  default     = true
}

variable "enable_http" {
  description = "Attach an HTTP listener. If HTTPS is enabled this listener redirects to 443; otherwise it forwards to the target group"
  type        = bool
  default     = true
}

variable "enable_internal_https" {
  description = "Attach an HTTPS listener on the internal ALB (requires certificate_arn)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listeners. Leave empty to run HTTP only"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listeners"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
}

variable "target_port" {
  description = "Application port on registered targets"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP health check path"
  type        = string
  default     = "/"
}

variable "target_ids" {
  description = "Optional instance IDs to register with both ALB target groups"
  type        = list(string)
  default     = []
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Enable HTTP/2 on the ALBs"
  type        = bool
  default     = true
}

variable "drop_invalid_header_fields" {
  description = "Drop invalid HTTP header fields"
  type        = bool
  default     = true
}

variable "access_logs" {
  description = "Optional S3 access logs block: { bucket, prefix, enabled }"
  type = object({
    bucket  = string
    prefix  = optional(string)
    enabled = optional(bool, true)
  })
  default = null
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}
