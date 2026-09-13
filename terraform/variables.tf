variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "The CIDR block for the subnet"
  type        = string
}

variable "availability_zone" {
  description = "The availability zone for the subnet"
  type        = string
}

variable "instances" {
  type = map(object({
    instance_type = string
    private_ip    = string
    role          = string
  }))
}

variable "ssh_cidr" {
  description = "The CIDR block for SSH access"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ami_id" {
  type        = string
  description = "AMI ID for Debian 12 (region-specific)"
}

variable "key_name" {
  type        = string
  description = "Name of your existing EC2 key pair for SSH access"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}


