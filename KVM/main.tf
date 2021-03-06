provider "libvirt" {
  uri = var.libvirt_keyfile == "" ? var.libvirt_uri : "${var.libvirt_uri}?keyfile=${var.libvirt_keyfile}"

}

resource "libvirt_volume" "img" {
  name   = "${var.edge_location}-${basename(var.image_uri)}"
  source = var.image_uri
  pool   = var.pool
}

