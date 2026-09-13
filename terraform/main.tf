module "vpc" {
  source            = "./modules/vpc"
  project_name      = var.project_name
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone

}


module "security_group" {
  source       = "./modules/security_group"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  ssh_cidr     = var.ssh_cidr
}

module "ec2" {
  for_each = var.instances

  source = "./modules/ec2"

  ami_id            = var.ami_id
  instance_type     = each.value.instance_type
  instance_name     = each.key
  private_ip        = each.value.private_ip
  key_name          = var.key_name
  subnet_id         = module.vpc.subnet_id
  security_group_id = module.security_group.security_group_id

  user_data = templatefile(
    "${path.root}/../user-data/base.sh.tftpl",
    {
      hostname = each.key
      role     = each.value.role
    }
  )
}
