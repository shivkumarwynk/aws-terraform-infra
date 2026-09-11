variable "region" {
  description = "Optional AWS region override; defaults to enterprise/common/config.json"
  type        = string
  default     = null
}

variable "name" {
  description = "Optional ALB name override; defaults to enterprise/common/config.json"
  type        = string
  default     = null
}

variable "env" {
  description = "Optional environment override; defaults to enterprise/common/config.json"
  type        = string
  default     = null
}

variable "vpc_name" {
  description = "Optional VPC Name tag override; defaults to enterprise/common/config.json"
  type        = string
  default     = null
}

variable "public_subnet_names" {
  description = "Optional public subnet Name tag overrides; defaults to enterprise/common/config.json"
  type        = list(string)
  default     = null
}

variable "private_subnet_names" {
  description = "Optional private subnet Name tag overrides; defaults to enterprise/common/config.json"
  type        = list(string)
  default     = null
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

variable "external_certificate_arn" {
  description = "ACM certificate ARN for the external HTTPS listener. Leave empty to keep the external ALB HTTP-only"
  type        = string
  default     = ""
}

variable "internal_certificate_arn" {
  description = "ACM certificate ARN for the internal HTTPS listener. Leave empty to keep the internal ALB HTTP-only"
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
