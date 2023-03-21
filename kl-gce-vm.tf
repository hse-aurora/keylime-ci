terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.55.0"
    }
  }
}

variable "image_name" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

provider "google" {
  project = "project-keylime"
  region  = "europe-west2"
  zone    = "europe-west2-c"
}

resource "google_compute_instance" "vm_instance" {
  name         = "keylime-${terraform.workspace}"
  machine_type = "f1-micro"
  tags         = ["allow-ssh"]

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
