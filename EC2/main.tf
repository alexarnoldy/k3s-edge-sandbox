# Terraform configuration

terraform {
  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      #      version = "1.14.0"
    }
  }
}


provider "aws" {
  region = "us-west-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = var.edge_location
  cidr = var.vpc_cidr

  azs = var.vpc_azs
  #  private_subnets = var.vpc_private_subnets
  public_subnets = var.vpc_public_subnets

  enable_nat_gateway = var.vpc_enable_nat_gateway

  tags = var.vpc_tags
}

module "ec2_first_server_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  name           = "${var.edge_location}-server"
  ami            = var.instance_ami
  instance_type  = var.server_instance_type
  key_name       = "aarnoldy_laptop"
  #  key_name		= "rancher-server"
  #  key_name		= aws_key_pair.aarnoldy_laptop.id
  vpc_security_group_ids = [aws_security_group.K3s_outside_sg.id, aws_security_group.K3s_local_sg.id]
  subnet_id              = module.vpc.public_subnets[0]
#  user_data = data.template_file.user_data.rendered

  tags = {
    Terraform   = "true"
    first_server   = "true"
  }
}

#data "template_file" "user_data" {
#    template = file("./k3s.sh")
#    vars = {
#      first_ip = module.ec2_first_server_instance.private_ip
#    }
#}

module "ec2_server_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  name           = "${var.edge_location}-server"
  instance_count = var.num_servers
  ami            = var.instance_ami
  instance_type  = var.server_instance_type
  key_name       = "aarnoldy_laptop"
  #  key_name		= "rancher-server"
  #  key_name		= aws_key_pair.aarnoldy_laptop.id
  vpc_security_group_ids = [aws_security_group.K3s_outside_sg.id, aws_security_group.K3s_local_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  depends_on = [module.ec2_first_server_instance]
}

module "ec2_agent_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  name           = "${var.edge_location}-agent"
  instance_count = var.num_agents
  ami            = var.instance_ami
  instance_type  = var.agent_instance_type
#  key_name       = "aarnoldy_laptop"
  vpc_security_group_ids = [aws_security_group.K3s_outside_sg.id, aws_security_group.K3s_local_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  depends_on = [module.ec2_first_server_instance]
}

#resource "aws_key_pair" "aarnoldy_laptop" {
#  key_name   = var.ssh_authorized_keys
#  public_key = var.ssh_public_key
#}

resource "aws_security_group" "K3s_local_sg" {
  name        = "${var.edge_location}-local-sg"
  description = "Cluster internal communication"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_local_rules
    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["proto"]
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

}

resource "aws_security_group" "K3s_outside_sg" {
  name        = "${var.edge_location}-outside-sg"
  description = "Cluster communication"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_outside_rules
    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["proto"]
      cidr_blocks = ingress.value["cidrs"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


}

#module "rancher_cluster" {
#  source = "./modules/rancher2"
#}

provider "rancher2" {
  alias = "rancher-demo"
  #  api_url    = "https://rancher-demo.susealliances.com/v3"
}

resource "rancher2_cluster" "k3s-cluster-instance" {
  provider    = rancher2.rancher-demo
  name        = "k3s-${var.edge_location}"
  description = "K3s imported cluster"
  labels      = var.cluster_labels
  #  labels = tomap({"location" = "north", "customer" = "BigMoney"})
}

data "rancher2_cluster" "k3s-cluster" {
  provider   = rancher2.rancher-demo
  name       = "k3s-${var.edge_location}"
  depends_on = [rancher2_cluster.k3s-cluster-instance]
}

#module "website_s3_bucket" {
#  source = "./modules/aws-s3-static-website-bucket"
#
#  bucket_name = "aarnoldy-20210509"
#
#  tags = {
#    Terraform   = "true"
#    Environment = "dev"
#  }
#}
