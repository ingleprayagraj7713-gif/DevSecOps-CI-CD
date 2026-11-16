variable "name" { type = string }
variable "ecr_repository_arn" { type = string }
variable "log_group_arn" { type = string }
variable "secret_arns" {
  type    = list(string)
  default = []
}
variable "kms_key_arns" {
  type    = list(string)
  default = []
}
