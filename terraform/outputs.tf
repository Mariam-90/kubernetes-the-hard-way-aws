output "instance_public_ips" {
  value = {
    for name, instance in module.ec2 :
    name => instance.instance_public_ip
  }
}

output "instance_private_ips" {
  value = {
    for name, instance in module.ec2 :
    name => instance.instance_private_ip
  }
}

output "instance_ids" {
  value = {
    for name, instance in module.ec2 :
    name => instance.instance_id
  }
}
