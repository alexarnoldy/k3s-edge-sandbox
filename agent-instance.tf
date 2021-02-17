data "template_file" "agent_commands" {
  template = file("cloud-init/commands.tpl")
  count    = join("", var.packages) == "" ? 0 : 1

  vars = {
    packages = join(", ", var.packages)
  }
}

data "template_file" "agent-cloud-init" {
  template = file("cloud-init/common.tpl")

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    commands    = join("\n", data.template_file.agent_commands.*.rendered)
    username    = var.username
    password    = var.password
    ntp_servers = join("\n", formatlist("    - %s", var.ntp_servers))
  }
}

resource "libvirt_volume" "agent" {
  name           = "${var.edge_location}-agent-volume-${count.index}"
  pool           = var.pool
  size           = var.agent_disk_size
  base_volume_id = libvirt_volume.img.id
  count          = var.k3s_agents
}

resource "libvirt_cloudinit_disk" "agent" {
  # needed when 0 agent nodes are defined
  count     = var.k3s_agents
  name      = "${var.edge_location}-agent-cloudinit-disk-${count.index}"
  pool      = var.pool
  user_data = data.template_file.agent-cloud-init.rendered
}

resource "libvirt_domain" "agent" {
  count     = var.k3s_agents
  name      = "${var.edge_location}-agent-${count.index}"
  memory    = var.agent_memory
  vcpu      = var.agent_vcpu
  cloudinit = element(libvirt_cloudinit_disk.agent.*.id, count.index)

  cpu = {
    mode = "host-passthrough"
  }

  disk {
    volume_id = element(libvirt_volume.agent.*.id, count.index)
  }

  network_interface {
    network_id     = libvirt_network.network.id
    hostname       = "${var.edge_location}-agent-${count.index}"
    addresses      = [cidrhost(lookup(var.cidr_mapping, var.edge_location), 14 + count.index)]
#    addresses      = [cidrhost(var.network_cidr, 14 + count.index)]
    wait_for_lease = true
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

