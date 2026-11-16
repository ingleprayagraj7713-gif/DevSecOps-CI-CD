variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "instance_type" { type = string }
variable "volume_size_gib" { type = number }
variable "provision_instance" {
  type    = bool
  default = true
}
