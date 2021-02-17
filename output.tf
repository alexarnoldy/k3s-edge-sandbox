output "ip_servers" {
  value = zipmap(
    libvirt_domain.server.*.network_interface.0.hostname,
    libvirt_domain.server.*.network_interface.0.addresses.0,
  )
}

output "ip_agents" {
  value = zipmap(
    libvirt_domain.agent.*.network_interface.0.hostname,
    libvirt_domain.agent.*.network_interface.0.addresses.0,
  )
}
