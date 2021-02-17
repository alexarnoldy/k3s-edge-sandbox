variable "libvirt_uri" {
  default     = "qemu:///system"
  description = "URL of libvirt connection - default to localhost"
}

variable "edge_location" {
  description = "Identifier to make all your resources unique and avoid clashes with other users of this terraform project"
}

variable "libvirt_keyfile" {
  default     = ""
  description = "The private key file used for libvirt connection - default to none"
}
####

variable "pool" {
  default     = "default"
  description = "Pool to be used to store all the volumes"
}

variable "image_uri" {
  #  default     = "images/SLES15-SP2-JeOS.x86_64-15.2-OpenStack-Cloud-GM.qcow2"
  description = "URL of the image to use"
}

variable "authorized_keys" {
  type        = list(string)
  description = "SSH keys to inject into all the nodes"
}

variable "ntp_servers" {
  type        = list(string)
  default     = ["0.novell.pool.ntp.org", "1.novell.pool.ntp.org", "2.novell.pool.ntp.org", "3.novell.pool.ntp.org"]
  description = "List of NTP servers to configure"
}

variable "packages" {
  type = list(string)

  default = [
    "which",
    "wget",
    "kernel-default",
    "-kernel-default-base"
  ]

  description = "List of packages to install on all nodes"
}

variable "username" {
  default     = "opensuse"
  description = "Username for the cluster nodes"
}

variable "password" {
  default     = "SUSE-linux"
  description = "Password for the cluster nodes"
}

variable "dns_domain" {
  type        = string
  default     = "sandbox.local"
  description = "Name of DNS Domain."
}

variable "cidr_mapping" {
  description = "CIDR mapping of subnets per K3s cluster deployed on the same KVM host."
  default = {
    "bangkok" = "10.111.1.0/24"
    "freetown" = "10.111.2.0/24"
    "munich" = "10.111.3.0/24"
    "sydney" = "10.111.4.0/24"
  }
}

#variable "network_cidr" {
#  type        = string
#  default     = "10.111.1.0/24"
#  description = "Network used by the cluster"
#}

variable "network_mode" {
  type        = string
  default     = "nat"
  description = "Network mode used by the cluster"
}

variable "k3s_servers" {
  default     = 1
  description = "Number of K3s server (master) nodes"
}

variable "server_memory" {
  default     = 4096
  description = "Amount of RAM for a server"
}

variable "server_vcpu" {
  default     = 2
  description = "Amount of virtual CPUs for a server"
}

variable "server_disk_size" {
  default     = "25769803776"
  description = "Disk size (in bytes)"
}

variable "k3s_agents" {
  default     = 2
  description = "Number of K3s agent (worker) nodes"
}

variable "agent_memory" {
  default     = 4096
  description = "Amount of RAM for a agent"
}

variable "agent_vcpu" {
  default     = 2
  description = "Amount of virtual CPUs for a agent"
}

variable "agent_disk_size" {
  default     = "25769803776"
  description = "Disk size (in bytes)"
}
