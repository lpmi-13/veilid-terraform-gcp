output "public_ip_ipv4" {
  value = [
    for instance in google_compute_instance.veilid : instance.network_interface.0.access_config.0.nat_ip
  ]
}

output "public_ip_ipv6" {
  value = [for instance in google_compute_instance.veilid : instance.network_interface.0.ipv6_access_config.0.external_ipv6]
}
