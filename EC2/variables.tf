# Input variable definitions


variable "ssh_public_key" {
  description = "Key to connect to the instance"
  type        = string
}

variable "vpc_name" {
  description = "Name of VPC"
  type        = string
  default     = "example-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1b", "us-west-1c"]
}

variable "vpc_private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "vpc_enable_nat_gateway" {
  description = "Enable NAT gateway for VPC"
  type        = bool
  default     = false
}

variable "vpc_tags" {
  description = "Tags to apply to resources created by VPC module"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}

variable "ingress_outside_rules" {
  default = [
    {
      from_port = 80
      to_port   = 80
      proto     = "tcp"
      cidrs     = ["0.0.0.0/0"]
    },
    {
      from_port = 443
      to_port   = 443
      proto     = "tcp"
      cidrs     = ["0.0.0.0/0"]
    },
    {
      from_port = 22
      to_port   = 22
      proto     = "tcp"
### Change for your public IP or to "0.0.0.0/0" for wide open
      cidrs     = ["91.193.113.129/32"]
    },
    {
      from_port = 2244
      to_port   = 2244
      proto     = "tcp"
### Change for your public IP or to "0.0.0.0/0" for wide open
      cidrs     = ["91.193.113.129/32"]
    },
    {
      from_port = 6443
      to_port   = 6443
      proto     = "tcp"
      cidrs     = ["0.0.0.0/0"]
    }
  ]
}

variable "ingress_local_rules" {
  default = [

    {
      from_port = 8472
      to_port   = 8472
      proto     = "udp"
    },

    {
      from_port = 10250
      to_port   = 10250
      proto     = "tcp"
    },

    {
      from_port = 2379
      to_port   = 2380
      proto     = "tcp"
    }
  ]
}

variable "instance_name_prefix" {
  description = "Name prefix for instances"
  type        = string
  default     = "my-ec2-cluster"
}

variable "num_servers" {
  description = "Number of server instances to create"
  type        = number
}

variable "num_agents" {
  description = "Number of agent instances to create"
  type        = number
}

variable "instance_ami" {
  description = "AMI for the instance, i.e. ami-05c558c169cfe8d99 for us-west-1, ami-0174313b5af8423d7 for us-west-2"
  type        = string
  default     = "ami-0174313b5af8423d7"
}

variable "server_instance_type" {
  description = "Type for the instance"
  type        = string
  default     = "t2.small"
}

variable "agent_instance_type" {
  description = "Type for the instance"
  type        = string
  default     = "t2.small"
}

#variable "ssh_authorized_keys" {
#  type    = string
#}

variable "cluster_labels" {
  type        = map(any)
  description = "Labels to be applied to imported cluster object in Rancher"
  default = {
    "status" = "standby"
  }
}

variable "edge_location" {
  description = "Identifier to make all your resources unique and avoid clashes with other users of this terraform project"
}

#variable "my_public_ip" {
#  description	= "Allow restricting security group to only allow SSH from one system. Must include CIDR notation"
#  type		= list
##  default	= ["99.73.163.16/32"]
#}

#variable "instance_type_map" {
#  description	= "Map of AMIs and instance types to create"
#  type		= map(string)
#  default	= {
#    instance-1	= "t2.small"
#    instance-2	= "t2.medium"
#    instance-3	= "t2.medium"
#  }
#}    
