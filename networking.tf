
resource "google_compute_network" "veilid_vpc" {
  project                 = "veilid-nodes"
  name                    = "veilid-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "veilid_subnet" {
  for_each      = toset(local.free_regions)
  name          = "veilid-subnet-${each.key}"
  ip_cidr_range = "10.0.${index(local.free_regions, each.key)}.0/24"
  # chop off the last two characters from the key to form a valid region
  region           = substr(each.key, 0, length(each.key) - 2)
  network          = google_compute_network.veilid_vpc.id
  ipv6_access_type = "EXTERNAL"
  stack_type       = "IPV4_IPV6"
}

resource "google_compute_firewall" "veilid_ports_ipv4" {
  for_each = toset(local.free_regions)
  provider = google
  name     = "inbound-connections-ipv4-${each.key}"
  network  = google_compute_network.veilid_vpc.name

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "5150"]
  }

  allow {
    protocol = "udp"
    ports    = ["5150"]
  }
}

resource "google_compute_firewall" "veilid_ports_ipv6" {
  for_each = toset(local.free_regions)
  provider = google
  name     = "inbound-connections-ipv6-${each.key}"
  network  = google_compute_network.veilid_vpc.name

  source_ranges = ["::/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "5150"]
  }

  allow {
    protocol = "udp"
    ports    = ["5150"]
  }
}
