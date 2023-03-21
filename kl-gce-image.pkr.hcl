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
  default = "master"
}

variable "a_tag" {
  type    = string
  default = "master"
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
    inline = [
      // Install Docker
      "sudo dnf -y install dnf-plugins-core",
      "sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo",
      "sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo systemctl enable --now docker",
      // Install the GCP credential helper for Docker to automatically retrieve the credentials of the service account associated with the GCE instance so that pulling images from GCR will succeed
      "curl -fsSL https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.6/docker-credential-gcr_linux_amd64-2.1.6.tar.gz | tar xz docker-credential-gcr",
      "chmod +x docker-credential-gcr",
      "sudo mv docker-credential-gcr /usr/bin/",
      "sudo docker-credential-gcr configure-docker",
      // Pull Keylime Docker images from GCR
      "sudo docker pull gcr.io/project-keylime/keylime_verifier:${var.vrt_tag}",
      "sudo docker pull gcr.io/project-keylime/keylime_registrar:${var.vrt_tag}",
      "sudo docker pull gcr.io/project-keylime/keylime_tenant:${var.vrt_tag}",
      "sudo docker pull gcr.io/project-keylime/keylime_agent:${var.a_tag}",
      // Create custom network bridge to allow containers to communicate with one another by name instead of IP address
      "sudo docker network create keylime-net",
      // Create containers from the images with the appropriate mappings to allow sharing of data between containers
      "sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-config-vol:/etc/keylime --net keylime-net -p 8880:8880 -p 8881:8881 --restart unless-stopped --name keylime_verifier gcr.io/project-keylime/keylime_verifier:${var.branch}",
      "sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-config-vol:/etc/keylime --net keylime-net -p 8890:8890 -p 8891:8891 --restart unless-stopped --name keylime_registrar gcr.io/project-keylime/keylime_registrar:${var.branch}",
      "sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-config-vol:/etc/keylime --net keylime-net --entrypoint /bin/bash --name keylime_tenant gcr.io/project-keylime/keylime_tenant:${var.branch}",
      // The Dockerfile provided for the agent does not currently work as is
      // "sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-config-vol:/etc/keylime --restart unless-stopped --name keylime_agent gcr.io/project-keylime/keylime_agent:${var.branch}"
      // TODO: Create new Dockerfile for agent
    ]
  }
}
