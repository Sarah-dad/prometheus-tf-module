variable "vpc_id" {}

variable "public_subnets" {
  type = "list"
}

variable "private_subnets" {
  type = "list"
}

variable "sg_bastion_id" {}
variable "ami" {}
variable "instance_flavor" {}
variable "volume_size" {}
variable "key_pair_name" {}
variable "application" {}
variable "component" {}
variable "certificate_prefix" {}
variable "subdomain" {}
variable "client" {}
variable "tld" {}
variable "env" {}
variable "monitoring_sec_group" {}
variable "tags" { type = "map" }
variable "gitlab_token" {}
variable "ansible_tag" {}
