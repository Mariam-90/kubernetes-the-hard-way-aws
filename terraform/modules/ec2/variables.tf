variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string

}
variable "instance_type" {
  description = "The instance type to use for the EC2 instance"
  type        = string
}
variable "key_name" {
  description = "The name of the key pair to use for the EC2 instance"
  type        = string
}
variable "subnet_id" {
  description = "The ID of the subnet to launch the EC2 instance in"
  type        = string
}
variable "project_name" {
  description = "The name of the project"
  type        = string
}
variable "security_group_id" {
  description = "The ID of the security group to associate with the EC2 instance"
  type        = string
}
