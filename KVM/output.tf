output "ip_servers" {
  value = zipmap(
    libvirt_domain.server.*.network_interface.0.hostname,
    libvirt_domain.server.*.network_interface.0.addresses
  )
}

output "ip_agents" {
  value = zipmap(
    libvirt_domain.agent.*.network_interface.0.hostname,
    libvirt_domain.agent.*.network_interface.0.addresses
  )
}

output "cluster_registration_token" {
  value = data.rancher2_cluster.k3s-cluster.cluster_registration_token[0]
  sensitive   = true
}
