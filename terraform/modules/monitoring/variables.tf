variable "name" { type = string }
variable "region" { type = string }
variable "jenkins_instance_id" {
  type     = string
  default  = null
  nullable = true
}
variable "jenkins_enabled" {
  type    = bool
  default = false
}
variable "cluster_name" { type = string }
variable "service_name" { type = string }
variable "load_balancer_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
variable "alarm_email" { type = string }
