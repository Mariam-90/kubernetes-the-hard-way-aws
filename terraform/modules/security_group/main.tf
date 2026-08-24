resource "aws_security_group" "k8s_sg" {
  description = "Security group for Kubernetes The Hard Way EC2 instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "ssh_ingress" {
  security_group_id = aws_security_group.k8s_sg.id

  cidr_ipv4   = var.ssh_cidr
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "internal_ingress" {
  security_group_id = aws_security_group.k8s_sg.id

  referenced_security_group_id = aws_security_group.k8s_sg.id

  ip_protocol = "-1"
}
