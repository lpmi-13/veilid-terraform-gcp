terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.7.0"
    }
  }
}

provider "google" {
  project = "veilid-nodes"
  # the region and zone here are just the default, and won't need to change if you want to run a
  # VM in a different zone, eg - us-central1-c, though you WILL need to change the configuration for
  # the google_compute_subnetwork, since those are in specific regions.
  region = "us-west1"
  zone   = "us-west1-c"
}

resource "google_compute_network" "veilid_vpc" {
  project                 = "veilid-nodes"
  name                    = "veilid-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "veilid_subnet" {
  name             = "veilid-subnet"
  ip_cidr_range    = "10.0.0.0/24"
  region           = "us-west1"
  network          = google_compute_network.veilid_vpc.id
  ipv6_access_type = "EXTERNAL"
}

resource "google_compute_firewall" "veilid_ports" {
  provider = google
  name     = "inbound-connections"
  network  = google_compute_network.veilid_vpc.name

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "5150", "5151"]
  }

  allow {
    protocol = "udp"
    ports    = ["5150", "5151"]
  }
}

resource "google_compute_instance" "veilid" {
  # I used a for_each here just because that's easiest to use no matter which value is uncommented in the
  # local.free_regions block, even though this is intended to only run one VM. Technically, if you run instances
  # in more than one of the "free_regions" the second one is NOT free.
  for_each = toset(local.free_regions)
  name     = "veilid-node-${each.key}"
  # this is the smallest VM GCP has, and qualifies for their free tier
  machine_type = "e2-micro"
  zone         = each.key

  boot_disk {
    initialize_params {
      # Ubuntu 22.04 AMD (E2-micro doesn't support ARM)
      image = "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20231030"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.veilid_subnet.name

    access_config {
      // We'll get an ephemeral public IP if we don't specify a public IP explicitly
      network_tier = "STANDARD"
    }
  }

  scheduling {
    automatic_restart = true
    min_node_cpus     = 0
    # If there's a maintenance event, the entire workload is moved to another physical machine automatically.
    # This means we don't lose any of the DHT (distributed hash table) values that veilid needs to function properly.
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  metadata = {
    # add your public ssh key contents here if you want to be able to log in and poke around
    ssh-keys = "veilid:PUT_YOUR_PUBLIC_SSH_KEY_CONTENTS_HERE"
    # this is the cloud init script used to install and configure the veilid-server
    user-data = file("./setup-veilid.yaml")
  }
}
