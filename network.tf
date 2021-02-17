resource "libvirt_network" "network" {
  name   = "${var.edge_location}-network"
  mode   = var.network_mode
  domain = var.dns_domain

  dns {
    enabled = true
  }

  addresses = [lookup(var.cidr_mapping, var.edge_location)]
#  addresses = [var.network_cidr]
}

