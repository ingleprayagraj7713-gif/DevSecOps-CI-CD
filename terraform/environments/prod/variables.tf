variable "aws_region" {
  type        = string
  description = "AWS deployment region."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Lowercase project identifier used in resource names."
  default     = "ypp-fiber"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "prod"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC IPv4 CIDR."
  default     = "10.40.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Two or more AZs in the selected region."
  default     = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Production requires at least two Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "One public subnet CIDR per AZ."
  default     = ["10.40.0.0/24", "10.40.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "One private application subnet CIDR per AZ."
  default     = ["10.40.10.0/24", "10.40.11.0/24"]
}

variable "nat_gateway_per_az" {
  type        = bool
  description = "Create a NAT gateway in every AZ for resilient egress (higher cost)."
  default     = true
}

variable "alb_ingress_cidrs" {
  type        = list(string)
  description = "Allowed IPv4 client CIDRs. Use 0.0.0.0/0 for a public website."
  default     = ["0.0.0.0/0"]
}

variable "health_check_path" {
  type        = string
  description = "HTTP health endpoint served by the container."
  default     = "/healthz"
}

variable "container_port" {
  type        = number
  description = "HTTP port exposed by the application container."
  default     = 8080
}

variable "image_tag" {
  type        = string
  description = "Immutable image tag, normally the Git commit SHA."
  default     = "bootstrap"
}

variable "task_cpu" {
  type        = number
  description = "Fargate task CPU units."
  default     = 256
}

variable "task_memory" {
  type        = number
  description = "Fargate task memory in MiB."
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Initial desired ECS task count."
  default     = 2
  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count cannot be negative."
  }
}

variable "min_capacity" {
  type        = number
  description = "Minimum tasks managed by ECS autoscaling."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum tasks managed by ECS autoscaling."
  default     = 10
}

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Grace period before ECS reacts to failed target health checks."
  default     = 60
}

variable "ecr_image_retention_count" {
  type        = number
  description = "Number of recent tagged images to retain."
  default     = 30
  validation {
    condition     = var.ecr_image_retention_count >= 1
    error_message = "Retain at least one ECR image."
  }
}

variable "application_secret_arns" {
  type        = map(string)
  description = "Optional environment variable name to Secrets Manager ARN mappings."
  default     = {}
  validation {
    condition = alltrue([
      for name in keys(var.application_secret_arns) :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name))
    ])
    error_message = "Secret map keys must be valid environment variable names."
  }
}

variable "application_secret_kms_key_arns" {
  type        = list(string)
  description = "Optional customer-managed KMS key ARNs used to decrypt app secrets."
  default     = []
}

variable "waf_rate_limit" {
  type        = number
  description = "Maximum requests per 5-minute window per IP before WAF blocks."
  default     = 2000
  validation {
    condition     = var.waf_rate_limit >= 10
    error_message = "WAF rate limit must be at least 10 requests per 5-minute window."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log and ALB log retention period."
  default     = 30
}

variable "alarm_email" {
  type        = string
  description = "Email subscription for CloudWatch alarm notifications; empty disables SNS."
  default     = ""
}

variable "jenkins_instance_type" {
  type        = string
  description = "Private Jenkins controller EC2 instance type; do not run builds on the controller."
  default     = "t3.large"
}

variable "provision_jenkins" {
  type        = bool
  description = "Create the Jenkins EC2 controller. Disable only when an organization SCP blocks EC2 launches."
  default     = true
}

variable "jenkins_volume_size_gib" {
  type        = number
  description = "Encrypted Jenkins controller root volume size."
  default     = 50
}
