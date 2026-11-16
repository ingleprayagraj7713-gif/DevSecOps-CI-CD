variable "name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "alb_ingress_cidrs" { type = list(string) }
variable "container_port" { type = number }
