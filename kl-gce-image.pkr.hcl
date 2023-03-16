packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "branch" {
  type    = string
  default = "master"
}

source "googlecompute" "fedora" {
  project_id   = "project-keylime"
  source_image = "fedora-cloud-base-gcp-37-1-7-x86-64"
  ssh_username = "packer"
  zone         = "europe-west2-c"
  image_name   = "packer-keylime-{{timestamp}}"
}

build {
  sources = ["sources.googlecompute.fedora"]

  provisioner "shell" {
    inline = [
      // Install Docker
      "sudo dnf -y install dnf-plugins-core",
      "sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo",
      "sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo systemctl start docker",
      // Install the GCP credential helper for Docker to automatically retrieve the credentials of the service account associated with the GCE instance so that pulling images from GCR will succeed
      "curl -fsSL https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.6/docker-credential-gcr_linux_amd64-2.1.6.tar.gz | tar xz docker-credential-gcr",
      "chmod +x docker-credential-gcr",
      "sudo mv docker-credential-gcr /usr/bin/",
      "sudo docker-credential-gcr configure-docker",
      // Pull Keylime Docker images from GCR
      "sudo docker pull gcr.io/project-keylime/keylime_registrar:${var.branch}",
      "sudo docker pull gcr.io/project-keylime/keylime_verifier:${var.branch}",
      "sudo docker pull gcr.io/project-keylime/keylime_tenant:${var.branch}",
      "sudo docker pull gcr.io/project-keylime/keylime_agent:${var.branch}",
      // Create containers from the images, start them, and set a restart policy
      "sudo docker run -itd --restart unless-stopped --name keylime_registrar gcr.io/project-keylime/keylime_registrar:${var.branch}",
      "sudo docker run -itd --restart unless-stopped --name keylime_verifier gcr.io/project-keylime/keylime_verifier:${var.branch}",
      "sudo docker run -itd --restart unless-stopped --name keylime_tenant gcr.io/project-keylime/keylime_tenant:${var.branch}",
      "sudo docker run -itd --restart unless-stopped --name keylime_agent gcr.io/project-keylime/keylime_agent:${var.branch}"
    ]
  }
}
