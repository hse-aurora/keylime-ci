packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "base_vmx" {
  type        = string
  default     = "./vm-templates/keylime-fedora-template/keylime-fedora-template.vmx"
  description = "The path to the VMX image to use as the base image when building the VM"
}

variable "use_zscaler" {
  type        = bool
  default     = false
  description = "Controls whether the zscaler root CA is installed in the VM to allow for corporate traffic inspection"
}

variable "use_proxy" {
  type        = bool
  default     = false
  description = "Controls whether the VM is configured to detect and use corporate proxy"
}

variable "use_swtpm" {
  type        = bool
  default     = true
  description = "Controls whether a SWTPM container will be installed and the Keylime agent configured to use it"
}

variable "vrt_tag" {
  type        = string
  default     = "latest"
  description = "The tag which identifies the version of the Docker images for the verifier, registrar and tenant to pull from GCR"
}

variable "a_tag" {
  type        = string
  default     = "latest"
  description = "The tag which identifies the version of the Docker image for the agent to pull from GCR"
}

variable "username" {
  type        = string
  default     = "kluser"
  description = "The name to use for the new OS user created in the VM"
}

variable "ssh_pub" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "The path to the public key to upload to the VM and used to authenticate when connecting over SSH in the future"
}

variable "oimg_label" {
  type        = string
  default     = "{{timestamp}}"
  description = "An identifying string to identify the VM image created by Packer"
}

variable "gcloud_creds" {
  type    = string
  default = ""
  description = "The path to the gcloud default credentials JSON file containing a valid, unexpired session token for GCP"
}

locals {
  git_clone_error_msg = "Could not clone the hse-aurora/hpeautoproxy repo. Check that your SSH public key has been authorised for the hse-aurora organisation on GitHub or that you are using a personal access token with the correct scope."
}

// VMWare VMX base image:
// Assumes a Fedora install with "packer" user preconfigured to perform passwordless sudo
source "vmware-vmx" "keylime-fedora" {
  source_path = "${pathexpand(var.base_vmx)}"
  ssh_username = "packer"
  ssh_password = "packer"
  shutdown_command = "sudo shutdown -P now"
  vm_name = "packer-keylime-${var.oimg_label}"
  vmx_data = {
    "displayName": "packer-keylime-${var.oimg_label}"
  }
  output_directory = "output-vms/packer-keylime-${var.oimg_label}"
  snapshot_name = "After Packer provisioning"
}

build {
  sources = ["sources.vmware-vmx.keylime-fedora"]

  // Create empty temporary directory within project directory (CMD.exe)
  provisioner "shell-local" {
    inline = ["rmdir /S /Q \"${path.root}\\tmp\" 2>nul", "mkdir \"${path.root}\\tmp\""]
    only_on = ["windows"]
  }

  // Create empty temporary directory within project directory (Bash)
  provisioner "shell-local" {
    inline_shebang = "/usr/bin/env bash"
    inline = ["rm -rf \"${path.root}/tmp\"", "mkdir \"${path.root}/tmp\""]
    only_on = ["linux"]
  }

  // Install zscaler root CA cert if use_zscaler is true
  provisioner "shell" {
    inline = [
      "if [[ \"$USE_ZSCALER\" == \"false\" ]]; then exit 0; fi",
      "wget https://pages.github.hpe.com/jean-snyman/zscaler/zscaler.crt -O /tmp/zscaler.crt",
      "sudo cp /tmp/zscaler.crt /etc/pki/ca-trust/source/anchors/",
      "sudo update-ca-trust",
      "rm /tmp/zscaler.crt"
    ]
    env = {
      "USE_ZSCALER" = "${var.use_zscaler}"
    }
  }

  // Download hpeautoproxy script if use_proxy is true (CMD.exe)
  provisioner "shell-local" {
    inline = [
      "cd \"${path.root}\\tmp\"",
      "if [\"%USE_PROXY%\"]==[\"false \"] mkdir hpeautoproxy & exit 0",
      "git clone -c core.autocrlf=false git@github.com:hse-aurora/hpeautoproxy.git || git clone -c core.autocrlf=false https://github.com/hse-aurora/hpeautoproxy.git || echo %GIT_CLONE_MSG%"
    ]
    env = {
      "USE_PROXY" = "${var.use_proxy}"
      "GIT_CLONE_MSG" = "${local.git_clone_error_msg}"
    }
    only_on = ["windows"]
  }

  // Download hpeautoproxy script if use_proxy is true (Bash)
  provisioner "shell-local" {
    inline_shebang = "/usr/bin/env bash"
    inline = [
      "cd \"${path.root}/tmp\"",
      "if [[ \"$USE_PROXY\" == \"false\" ]]; then mkdir hpeautoproxy; exit 0; fi",
      "git clone git@github.com:hse-aurora/hpeautoproxy.git || git clone https://github.com/hse-aurora/hpeautoproxy.git || echo \"$GIT_CLONE_MSG\""
    ]
    env = {
      "USE_PROXY" = "${var.use_proxy}"
      "GIT_CLONE_MSG" = "${local.git_clone_error_msg}"
    }
    only_on = ["linux"]
  }

  // Copy hpeautoproxy directory to VM
  provisioner "file" {
    source = "${path.root}/tmp/hpeautoproxy"
    destination = "/tmp"
    generated = true
  }

  // Install hpeautoproxy in the VM if use_proxy is true
  provisioner "shell" {
    inline = [
      "if [[ \"$USE_PROXY\" == \"false\" ]]; then exit 0; fi",
      "chmod 755 /tmp/hpeautoproxy/install.sh",
      "cd /tmp/hpeautoproxy/",
      "sudo /tmp/hpeautoproxy/install.sh -d -c -t /etc/skel/.bashrc -s",
      "rm -r /tmp/hpeautoproxy"
    ]
    env = {
      "USE_PROXY" = "${var.use_proxy}"
    }
  }

  // Copy gcloud credentials file to temporary location (CMD.exe)
  provisioner "shell-local" {
    inline = [
      "cd \"${path.root}\\tmp\"",
      "type nul > gcloud_application_default_credentials.json",
      "if defined GCLOUD_CREDS copy /y \"%GCLOUD_CREDS%\" gcloud_application_default_credentials.json"
    ]
    env = {
      "GCLOUD_CREDS" = "${pathexpand(var.gcloud_creds)}"
    }
    only_on = ["windows"]
  }

  // Copy gcloud credentials file to temporary location (Bash)
  provisioner "shell-local" {
    inline_shebang = "/usr/bin/env bash"
    inline = [
      "cd \"${path.root}/tmp\"",
      "touch gcloud_application_default_credentials.json",
      "if [[ \"$GCLOUD_CREDS\" != \"\" ]]; then",
      "  cp -f \"$GCLOUD_CREDS\" gcloud_application_default_credentials.json",
      "fi"
    ]
    env = {
      "GCLOUD_CREDS" = "${pathexpand(var.gcloud_creds)}"
    }
    only_on = ["linux"]
  }

  // Copy gcloud session from temporary location to VM
  provisioner "file" {
    source = "${path.root}/tmp/gcloud_application_default_credentials.json"
    destination = "/tmp/gcloud_application_default_credentials.json"
    generated = true
  }

  // Move gcloud credentials file to correct location
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /root/.config/gcloud",
      "sudo cp /tmp/gcloud_application_default_credentials.json /root/.config/gcloud/application_default_credentials.json",
      "rm /tmp/gcloud_application_default_credentials.json"
    ]
  }

  // Run setup scripts:
  // 1. Create Docker containers from images pulled from GCR
  // 2. Set up vscode remote development
  // 3. Expose Keylime source, config and data directories in Docker volumes by linking them in familiar locations
  // 4. Add login scripts to prompt the user to set their password on first login
  // 5. Add script to display informational banners on startup and login
  // 6. Define aliases to simply common actions for Keylime development
  provisioner "shell" {
    scripts = ["./helpers/create-containers.sh", "./helpers/setup-vscode-server.sh", "./helpers/create-kl-symlinks.sh", "./helpers/add-pw-login-scripts.sh", "./helpers/set-banners.sh", "./helpers/define-aliases.sh"]
    env = {
      "VRT_TAG" = "${var.vrt_tag}"
      "A_TAG" = "${var.a_tag}",
      "USE_SWTPM" = "${var.use_swtpm}"
    }
  }

  // Install useful tools
  provisioner "shell" {
    inline = ["sudo dnf -y install git nano"]
  }
  
  // Create new OS user 
  provisioner "shell" {
    inline = [
      "sudo useradd -m -G wheel \"${var.username}\""
    ]
  }

  // Upload SSH public key
  provisioner "file" {
    source = "${pathexpand(var.ssh_pub)}"
    destination = "/tmp/ssh_key.pub"
  }

  // Copy SSH public key to new user's authorised_keys file and disable SSH password authentication
  provisioner "shell" {
    inline = [
      "sudo mkdir -p \"/home/${var.username}/.ssh/\"",
      "sudo touch \"/home/${var.username}/.ssh/authorized_keys\"",
      "cat /tmp/ssh_key.pub | sudo tee -a \"/home/${var.username}/.ssh/authorized_keys\"",
      "sudo chown -R \"${var.username}:${var.username}\" \"/home/${var.username}/.ssh/\"",
      "sudo sed -i 's/^#PasswordAuthentication yes$/PasswordAuthentication no/' /etc/ssh/sshd_config",
      "rm /tmp/ssh_key.pub"
    ]
  }

  // Set hostname to match VM name in VMWare
  provisioner "shell" {
    inline = [
      "sudo hostnamectl set-hostname \"packer-keylime-${var.oimg_label}\""
    ]
  }

  // Disable "packer" user
  provisioner "shell" {
    inline = [
      "sudo su \"${var.username}\"",
      "sudo usermod -L packer"
    ]
  }

  // Delete temporary directory (CMD.exe)
  provisioner "shell-local" {
    inline = ["rmdir /S /Q \"${path.root}\\tmp\" 2>nul"]
    only_on = ["windows"]
  }

  // Delete temporary directory (Bash)
  provisioner "shell-local" {
    inline_shebang = "/usr/bin/env bash"
    inline = ["rm -rf \"${path.root}/tmp\""]
    only_on = ["linux"]
  }
}
