variable "container_image" {
  description = "Container image used by both example ECS services"
  type        = string
  default     = "public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest"
}

variable "container_port" {
  description = "Container and ALB target group port"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU units reserved by each task"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory in MiB reserved by each task"
  type        = number
  default     = 1024
}

variable "ip_service_desired_count" {
  description = "Desired task count for the awsvpc/IP target service"
  type        = number
  default     = 1
}

variable "instance_service_desired_count" {
  description = "Desired task count for the host/instance target service"
  type        = number
  default     = 1
}

variable "alb_type" {
  description = "ALB target groups used by ECS services"
  type        = string
  default     = "external"

  validation {
    condition     = contains(["external", "internal"], var.alb_type)
    error_message = "alb_type must be either \"external\" or \"internal\"."
  }
}

variable "storage_size_gib" {
  description = "Storage allocated to each ECS Managed Instance"
  type        = number
  default     = 30
}

variable "minimum_vcpu" {
  description = "Minimum vCPU count for ECS Managed Instance selection"
  type        = number
  default     = 2
}

variable "maximum_vcpu" {
  description = "Maximum vCPU count for ECS Managed Instance selection"
  type        = number
  default     = 8
}

variable "minimum_memory_mib" {
  description = "Minimum memory for ECS Managed Instance selection"
  type        = number
  default     = 2048
}

variable "maximum_memory_mib" {
  description = "Maximum memory for ECS Managed Instance selection"
  type        = number
  default     = 8192
}

variable "private_subnet_names" {
  description = "Optional private subnet Name tag overrides"
  type        = list(string)
  default     = null
}
