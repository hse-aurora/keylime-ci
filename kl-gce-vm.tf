terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.55.0"
    }

    time = {
      source = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

variable "image_name" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "ovmid" {
  type = string
  nullable = true
  default = null
}

resource "time_static" "activation_date" {}

provider "google" {
  project = "project-keylime"
  region  = "europe-west2"
  zone    = "europe-west2-c"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-keylime-${coalesce(var.ovmid, time_static.activation_date.unix)}"
  machine_type = "n1-standard-2"
  tags         = ["allow-ssh"]
  allow_stopping_for_update = true

  metadata = {
    ssh-keys = "kluser:${file(var.ssh_public_key)}"
  }

  boot_disk {
    initialize_params {
      image = "project-keylime/${var.image_name}"
    }
  }

  network_interface {
    network = "keylime"
    subnetwork = "keylime-london"

    access_config {
      network_tier = "STANDARD"
    }
  }
}

output "vm_name" {
  value = google_compute_instance.vm_instance.name
}

output "ephemeral_vm_ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}