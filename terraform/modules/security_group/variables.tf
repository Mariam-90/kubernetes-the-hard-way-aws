variable "project_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the security group will be created"
}


variable "ssh_cidr" {
  description = "CIDR allowed to access EC2 instances via SSH"
  type        = string
}
