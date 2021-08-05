# Terraform configuration

terraform {
  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      alias = "rancher-demo"
      #      version = "1.14.0"
    }
    aws = {
      region = "us-west-1"
    }
  }
}

provider "rancher2" {
  alias = "rancher-demo"
}


#### Comment out the section below if a Rancher server is not available ####
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
#### Comment out the section above if a Rancher server is not available ####


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = var.edge_location
  cidr = var.vpc_cidr

  azs = var.vpc_azs
  #  private_subnets = var.vpc_private_subnets
  public_subnets = var.vpc_public_subnets

  enable_nat_gateway = var.vpc_enable_nat_gateway

  tags = {
    KubernetesCluster   = var.edge_location
  }
}

module "ec2_first_server_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  name           = "${var.edge_location}-server"
  ami            = var.instance_ami
  instance_type  = var.server_instance_type
  key_name       = var.ssh_public_key
  iam_instance_profile = aws_iam_instance_profile.k3s_ebs_profile.name
  vpc_security_group_ids = [aws_security_group.K3s_outside_sg.id, aws_security_group.K3s_local_sg.id]
  subnet_id              = module.vpc.public_subnets[0]
#  user_data = data.template_file.user_data.rendered

  tags = {
    KubernetesCluster   = var.edge_location
    Terraform   = "true"
    first_server   = "true"
  }
}

module "ec2_server_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.12.0"

  name           = "${var.edge_location}-server"
  instance_count = (var.num_servers - 1)
  ami            = var.instance_ami
  instance_type  = var.server_instance_type
  key_name       = var.ssh_public_key
  iam_instance_profile = aws_iam_instance_profile.k3s_ebs_profile.name
  vpc_security_group_ids = [aws_security_group.K3s_outside_sg.id, aws_security_group.K3s_local_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    KubernetesCluster   = var.edge_location
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
  key_name       = var.ssh_public_key
  iam_instance_profile = aws_iam_instance_profile.k3s_ebs_profile.name
  vpc_security_group_ids = [aws_security_group.K3s_outside_sg.id, aws_security_group.K3s_local_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    KubernetesCluster   = var.edge_location
    Terraform   = "true"
    Environment = "dev"
  }
  depends_on = [module.ec2_first_server_instance]
}

#resource "aws_key_pair" "ec2-key-pair" {
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

resource "aws_iam_role" "k3s_ebs_role" {
  name = "k3s_ebs_role"

  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
})

  tags = {
    KubernetesCluster   = var.edge_location
    Terraform   = "true"
  }
}


resource "aws_iam_instance_profile" "k3s_ebs_profile" {
  name = "k3s_ebs_profile"
  role = aws_iam_role.k3s_ebs_role.name
}

resource "aws_iam_role_policy" "k3s_ebs_role_policy" {
  name = "k3s_ebs_role_policy"
  role = aws_iam_role.k3s_ebs_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:AttachVolume",
                "ec2:DetachVolume",
                "ec2:ModifyVolume",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInstances",
                "ec2:DescribeSnapshots",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumesModifications"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:snapshot/*"
            ],
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": [
                        "CreateVolume",
                        "CreateSnapshot"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteTags"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:snapshot/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVolume"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "aws:RequestTag/ebs.csi.aws.com/cluster": "true"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVolume"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "aws:RequestTag/CSIVolumeName": "*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVolume"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "aws:RequestTag/kubernetes.io/cluster/*": "owned"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteVolume"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteVolume"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/CSIVolumeName": "*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteVolume"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/kubernetes.io/cluster/*": "owned"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/CSIVolumeSnapshotName": "*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
                }
            }
        }
    ]
})
}


#module "website_s3_bucket" {
#  source = "./modules/aws-s3-static-website-bucket"
#
#  bucket_name = "bucket-20210509"
#
#  tags = {
#    Terraform   = "true"
#    Environment = "dev"
#  }
#}
