data "template_file" "server_commands" {
  template = file("cloud-init/commands.tpl")
  count    = join("", var.packages) == "" ? 0 : 1

  vars = {
    packages = join(", ", var.packages)
  }
}

data "template_file" "server-cloud-init" {
  template = file("cloud-init/common.tpl")

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    commands        = join("\n", data.template_file.server_commands.*.rendered)
    username        = var.username
    password        = var.password
    ntp_servers     = join("\n", formatlist("    - %s", var.ntp_servers))
  }
}

resource "libvirt_volume" "server" {
  name           = "${var.edge_location}-server-volume-${count.index}"
  pool           = var.pool
  size           = var.server_disk_size
  base_volume_id = libvirt_volume.img.id
  count          = var.k3s_servers
}

resource "libvirt_cloudinit_disk" "server" {
  # needed when 0 server nodes are defined
  count     = var.k3s_servers
  name      = "${var.edge_location}-server-cloudinit-disk-${count.index}"
  pool      = var.pool
  user_data = data.template_file.server-cloud-init.rendered
}

resource "libvirt_domain" "server" {
  count     = var.k3s_servers
  name      = "${var.edge_location}-server-${count.index}"
  memory    = var.server_memory
  vcpu      = var.server_vcpu
  cloudinit = element(libvirt_cloudinit_disk.server.*.id, count.index)

  cpu = {
    mode = "host-passthrough"
  }

  disk {
    volume_id = element(libvirt_volume.server.*.id, count.index)
  }

  network_interface {
    network_id     = libvirt_network.network.id
    hostname       = "${var.edge_location}-server-${count.index}"
    addresses      = [cidrhost(lookup(var.cidr_mapping, var.edge_location), 11 + count.index)]
#    addresses      = [cidrhost(var.network_cidr, 11 + count.index)]
    wait_for_lease = true
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

