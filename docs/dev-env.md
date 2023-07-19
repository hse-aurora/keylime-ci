# How to: Set up a New Containerised Development Environment

This guide covers how to use the automation tools in this repo to set up a new Keylime development environment in a VMWare VM which you can access through SSH or VS Code's remote development feature.

## Overview

To accomplish this task, we need to perform a number of steps. At a high level, these are:

1. Build container images for each of the Keylime components (verifier, registrar, tenant and agent).
2. Push these images to a container registry (e.g., GCR).
3. Create a VM in VMWare Workstation and deploy containers to the VM using images from the registry.

Steps 1 and 2 are performed by the [`kl-deploy-images.sh`](kl-deploy-images.sh.md) script while step 3 is handled by [Packer](https://www.hashicorp.com/products/packer) and the [`kl-vmware-image.pkr.hcl`](kl-vmware-image.pkr.hcl.md) configuration file.

In addition to deploying containers, [`kl-vmware-image.pkr.hcl`](kl-vmware-image.pkr.hcl.md) performs numerous setup functions to create a streamlined and straightforward developer experience. These are [listed](kl-vmware-image.pkr.hcl.md#additional-tasks) in the file's reference documentation.

## Prerequisites

### OS Environment and Hypervisor

As the scripts in this repo all assume a Unix environment, it is suggested that you either set up your development environment on a Linux PC, or a Windows machine with WSL2 installed ([instructions](https://learn.microsoft.com/en-us/windows/wsl/install)). In either case, VMWare Workstation version 16 or greater is expected to be installed.

Theoretically, this should also work on macOS with VMWare Fusion, but this has not been tested.

### Container Registry

You will need a container registry to which to push your built images. The automation tools in this repo support two different scenarios:

1. **publishing your built Docker images publicly**, in which case any container registry can be used; and
2. **keeping your Docker images in a private repository**, for which only Google Container Registry (GCR) is currently supported.

You can use a container registry other than GCR to keep your private images, but doing so will require you to modify the Packer file ([`kl-vmware-image.pkr.hcl`](kl-vmware-image.pkr.hcl.md)) to handle authentication for your registry.

### Linux Dependencies

If you are performing these steps on a Linux machine, you will need to install:

- [Docker Engine](https://docs.docker.com/engine/install/#server)
- [Packer](https://developer.hashicorp.com/packer/downloads)
- [The gcloud CLI](https://cloud.google.com/sdk/docs/install) (if you are using GCR)
- Git

### Windows Dependencies

If you are instead using a Windows machine, then you will need to install:

- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- [Packer](https://developer.hashicorp.com/packer/downloads)

Additionally, you will need the following installed in the WSL2 environment:

- [The gcloud CLI](https://cloud.google.com/sdk/docs/install) for your WSL2 Linux distro (if you are using GCR) ***
- Git

Optionally, you may want to install [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/install).

## Downloading the Automation Tools

Obtain a local copy of this repo by running:

```
git clone https://github.com/hse-aurora/keylime-ci.git
cd keylime-ci
```

The instructions below assume you are in the keylime-ci directory.

> **Note** (**WSL2 users**): You should be able to access files on your Windows filesystem from the WSL2 environment, e.g., `C:\Users\me\keylime-ci` is accessible in WSL2 from `/mnt/c/Users/me/keylime-ci`.

## Building the Virtual Machine

1. **Download the VMWare Template Image**

    When Packer builds your VM in subsequent steps, it is given an existing VMX file to use as the base. You can download and extract a Fedora 37 image by running these commands from your Unix terminal:

    ```
    wget https://hpe-keylime-public.storage.googleapis.com/vm-templates/keylime-fedora-template.tar.gz -O vm-templates/keylime-fedora-template.tar.gz
    tar xzvf vm-templates/keylime-fedora-template.tar.gz
    rm vm-templates/keylime-fedora-template.tar.gz
    ```

    This file may take a while to download, so you may wish to proceed with the next steps in the meantime.

2. **Authenticate with Docker Hub**

    Docker Hub has somewhat aggressive IP address-based rate limiting for unauthenticated users. To sidestep this, it is suggested you create a free [Docker Hub](https://hub.docker.com/) account.

    From a Unix terminal, run `docker login` command to log in.

    > **Note** (**WSL2 users**): If you have Docker Desktop for Windows installed and running, the `docker` CLI should automatically be available from your WSL2 shell. If not, open Docker Desktop and ensure to check **Use the WSL 2 based engine** in Settings > General and **Enable integration with my default WSL distro** in Settings > Resources > WSL Integration.

3. **Allow Docker to Push to Your Container Registry**

    This step will be dependent on which container registry you are using. If you are using Docker Hub, you can skip this step.
    
    To use GCP Container Registry, run these commands from your Unix terminal:

    ```
    gcloud auth login --no-launch-browser --update-adc
    gcloud auth configure-docker
    ```

    Accept the default config when prompted.

    > **Note**: If your Docker installation runs as the root user on your system, you will need to run the above commands prefixed with `sudo` (they will still appear to complete successfully without `sudo` but will not modify the correct configuration). You can test whether or not this is the case by seeing if `docker run hello-world` completes successfully without `sudo`. If in doubt, simply run the `gcloud ...` commands twice, once with `sudo` and once without.

    > **Note** (**WSL2 users**): You should not need `sudo` for the above commands.

4. **Build the Keylime Container Images And Push to Registry**

    Assuming you have a copy of the Keylime Python source at `~/code/keylime` and the Rust source at `~/code/rust-keylime`, run the following commands in your Unix terminal:

    ```
    # Build containers for the verifier, registrar and tenant:
    ./kl-deploy-images.sh -d ~/code/keylime -c vrt -p <docker-repo-uri> -t <res-label>
    # Build container for the agent:
    ./kl-deploy-images.sh -d ~/code/rust-keylime -c a -p <docker-repo-uri> -t <res-label>
    ```

    Replace `<docker-repo-uri>` above with the URI of the repository at your Docker container registry which should receive the built images. `<res-label>` can be any string of your choice to help you identify the built images.

    > **Note** (**HPE employees**): Replace `<docker-repo-uri>` above with `gcr.io/project-keylime`.

    If you would like to build from a remote Git repo directly, use `-r` (to specify the URL) and `-b` (for the branch) instead of `-d` above. See [the reference docs](kl-deploy-images.sh.md) for the full list of options that the shell script supports.

5. **Set Packer Input Variables**

    The Packer configuration file (`kl-vmware-image.pkr.hcl`) leaves a number of values to be defined by the user. Default values for these variables are given in `defaults/kl-vmware-image.pkrvars.hcl`. Make a copy of this file and then edit it's values as appropriate:

    ```shell
    cp defaults/kl-vmware-image.pkrvars.hcl .
    nano kl-vmware-image.pkrvars.hcl # Or editor of your choice
    ```

    At minimum, you will likely wish to set `vrt_tag`, `a_tag`, and `oimg_label` to match `<res-label>` chosen in the previous step. You'll also want to set `gcloud_creds` to your `application_default_credentials.json` file on your system.

    > **Note** (**HPE employees**): It is suggested that you set `use_zscaler` and `use_proxy` to true.

6. **Build the VMWare Image**

    > **Note** (**WSL2 users**): The VMWare plugin for Packer expects to be on the same system where VMWare Workstation is installed, so you should perform these steps from Powershell or the Command Prompt.

    First, obtain the necessary Packer plugins by running `packer init kl-vmware-image.pkr.hcl`. Then, run the following command to build your VM image:

    ```
    packer build -var-file="kl-vmware-image.pkrvars.hcl" kl-vmware-image.pkr.hcl
    ```

## Connecting to Your New VM

Once Packer finishes building your VM and you start it from within VMWare, the assigned IP address will be shown before the login prompt. You can then connect to it via SSH in the usual way: `ssh <username>@<vm-ip-address>`. You will be authenticated by way of public key cryptography, using the key specified in the `kl-vmware-image.pkvars.hcl` file in step 4 above.

On your first login, you will be prompted to set a password for your user account. In the default configuration, you will need to provide this password when invoking sudo.

### Editing Source Code in VS Code

The image generated by Packer includes a number of alterations to the OS configuration and VS Code server software to enable editing of source code exposed in Docker volumes.

Making use of this is as simple as clicking the blue **›‹** icon (*Open a Remote Window*) in the bottom-left corner of any open VS Code window and selecting **Connect to Host... (Remote-SSH)**. Alternatively, open the command palette (Ctrl+Shift+P) and start typing to select "Remote-SSH: Connect to Host...".

In the textbox, enter "<username>@<vm-ip-address>" as when connecting in the regular way via SSH. Select "Linux" when asked to select the operating system.

To open the Keylime source files, once the connection is established, click **File** > **Open Folder...**. You can then choose to open any one of the following directories:

- `/root/keylime`: Python source for server components
- `/root/rust-keylime`: Rust source for agent
- `/root/.config/keylime`: config files for the server components (also available at /etc/keylime)
- `/root/.config/rust-keylime`: config files for the agent (also available at /etc/rust-keylime)
- `/root/.kl-data`: data directory (also available at /var/lib/keylime)

You can open multiple of these directories by opening multiple windows in the usual way from the **File** menu, or access them all in the same window by choosing to open `/root`.

### Restarting the Registrar and Verifier

While working in VS Code, you can open a new terminal on the VM by pressing Ctrl+Shift+' (the apostrophe key). Then, you can run `sudo klrestart r` or `sudo klrestart v` to restart the registrar and verifier containers respectively.

### Recompiling the Agent

To recompile the agent, run `sudo klrebuild`. You may also want to restart the agent container by running `sudo klrestart a`.

### Using the Keylime Tenant

You can access the Keylime CLI by running `sudo keylime_tenant <args...>` which is aliased to the appropriate `docker run ...` command to create a container based on the tenant image and execute the `keylime_tenant` executable within the container.