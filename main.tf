terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.33.0"
    }
  }
}

provider "google" {
  project = local.project_name
  # the region and zone here are just the default, and won't need to change if you want to run a
  # VM in a different zone, eg - us-central1-c, though you WILL need to change the configuration for
  # the google_compute_subnetwork, since those are in specific regions.
  region = "us-west1"
  zone   = "us-west1-c"
}

resource "google_project" "veilid-nodes" {
  name = local.project_name
  # these don't have to be the same, but it's simpler this way. Feel free to change the project ID
  # if you want, though you won't really need to use it for anything.
  project_id      = local.project_name
  billing_account = data.google_billing_account.veilid.id
  deletion_policy = "DELETE"
}

resource "google_project_service" "compute_api" {
  project = local.project_name
  service = "compute.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_on_destroy = true
}

data "google_billing_account" "veilid" {
  # this is the default billing account that gets created
  display_name = "My Billing Account"
  open         = true
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
    subnetwork = google_compute_subnetwork.veilid_subnet[each.key].name
    stack_type = "IPV4_IPV6"

    access_config {
      // We'll get an ephemeral public IP if we don't specify a public IP explicitly
      network_tier = "STANDARD"
    }

    ipv6_access_config {
      name         = "External IPv6"
      network_tier = "PREMIUM"
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
