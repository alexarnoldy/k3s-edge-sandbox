# Output variable definitions

output "vpc_public_subnets" {
  description = "IDs of the VPC's public subnets"
  value       = module.vpc.public_subnets
}

output "ec2_first_server_instance_public_ip" {
  description = "Public IP address of first EC2 instance"
  value       = module.ec2_first_server_instance.public_ip
}

output "ec2_first_server_instance_private_ip" {
  description = "Private IP address of first EC2 instance"
  value       = module.ec2_first_server_instance.private_ip
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cidr" {
  value = module.vpc.vpc_cidr_block
}
