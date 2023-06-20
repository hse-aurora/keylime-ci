packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "vrt_tag" {
  type    = string
  default = "latest"
}

variable "a_tag" {
  type    = string
  default = "latest"
}

variable "oimgid" {
  type    = string
  default = "{{timestamp}}"
}

source "googlecompute" "fedora" {
  project_id   = "project-keylime"
  source_image = "fedora-cloud-base-gcp-37-1-7-x86-64"
  ssh_username = "packer"
  zone         = "europe-west2-c"
  machine_type = "n1-standard-2" // f1-micro takes forever to perform the build
  image_name   = "packer-keylime-${var.oimgid}"
}

build {
  sources = ["sources.googlecompute.fedora"]

  provisioner "shell" {
    scripts = ["./helpers/create-containers.sh"]
    env = {
      "VRT_TAG" = "${var.vrt_tag}"
      "A_TAG" = "${var.a_tag}"
    }
  }
}