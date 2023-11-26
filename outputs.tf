output "public_ip" {
  value = [
    for instance in google_compute_instance.veilid : instance.network_interface.0.access_config.0.nat_ip
  ]
}
