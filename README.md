# Keylime CI

This repo contains files to support continuous integration of Keylime in GCP. The key components are:

- **kl-deploy-images.sh**: Bash script which retrieves Keylime source code, builds Docker images for the various Keylime components (the registrar, verifier, tenant and agent), and pushes the images to the GCP container registry.
- **kl-gce-image.pkr.hcl**: [Packer](https://www.hashicorp.com/products/packer) configuration file for building VM images for GCP Compute Engine with containers for each of the Keylime components.
- **kl-gce-vm.tf**: [Terraform](https://www.terraform.io/) configuration file for instantiating a VM from an image built by Packer.

These have been designed to automate tasks with GitHub Actions, but can also be run locally to quickly spin up extra development or testing environments.

## Contents

- [Requirements](#requirements)
  - [Authenticating to GCP](#authenticating-to-gcp)
- [Quickstart Guide](#quickstart-guide)
- [Reference Documentation](#reference-documentation)
  - [kl-deploy-images.sh](#kl-deploy-imagessh)
  - [kl-gce-image.pkr.hcl](#kl-gce-imagepkrhcl)
  - [kl-gce-vm.tf](#kl-gce-vmtf)
- [Future Evolutions](#future-evolutions)
- [Contribution Guidelines](#contribution-guidelines)

## Requirements

The files in this repo have the following dependencies:

- [Docker Engine](https://docs.docker.com/engine/) or [Docker Desktop](https://docs.docker.com/desktop/) (required by kl-deploy-images.sh)
- Git (required if you wish to use kl-deploy-images.sh to fetch Keylime source from a remote repository)
- [Packer](https://www.hashicorp.com/products/packer) (required to use kl-gce-image.pkr.hcl)
- [Terraform](https://www.terraform.io/) (required to use kl-gce-vm.tf)

Additionally, the files and scripts in this repo all require the appropriate credentials to authenticate to GCP.

### Authenticating to GCP

There are a few different ways to authenticate to GCP but it usually easiest to use the [gcloud](https://cloud.google.com/sdk/gcloud) CLI. As alternative, when employing the files in this repo in a GitHub Actions workflow, the [auth action](https://github.com/google-github-actions/auth) can be used instead.

To authenticate using the gcloud CLI, make sure the CLI is installed and then run `gcloud auth login`.

If you wish to use the kl-deploy-images.sh script to push images to GCR, you also need to configure Docker to use a GCP authentication provider. gcloud can do this automatically if you run `gcloud auth configure-docker` (you can accept the default options).

## Quickstart Guide

To provision a new deployment of Keylime in GCP:

1. Clone this repo to your machine:

    ```shell
    git clone git@github.com:hse-aurora/keylime-ci.git
    cd keylime-ci
    ```

2. Choose an identifier to attach to the resources that will be provisioned in GCP. This should describe the environment (e.g., "dev" or "stage"). If you are using these files to set up a development environment for yourself, it is suggested that you include your name to disambiguate your VMs from those of your team members. 

    Set your chosen identifier as an environment variable:

    ```shell
    export GCP_ID="dev-jean.snyman-$(date +%s)"
    ```

3. Build Docker images for the verifier, registrar and tenant using the source location of your choice and push these to GCR.

    To base your images on the official repo:

    ```shell
    ./kl-deploy-images.sh -r git@github.com:keylime/keylime.git -c vrt -p gcr.io/project-keylime -t "$GCP_ID" -w
    ```

    To base your images on a local clone or fork:

    ```shell
    ./kl-deploy-images.sh -d <path_to_kl_dir> -c vrt -p gcr.io/project-keylime -t "$GCP_ID" -w
    ```

    where `<path_to_kl_dir>` is the path, relative to your current working directory, to the directory containing the Python source code for the server-side components of Keylime.

4. Build a Docker image for the agent using the source location of your choice and, again, pushing this to GCR.

    To base your image on the official repo:

    ```shell
    ./kl-deploy-images.sh -r git@github.com:keylime/rust-keylime.git -c a -p gcr.io/project-keylime -t "$GCP_ID" -w
    ```

    To base your image on a local clone or fork:

    ```shell
    ./kl-deploy-images.sh -d <path_to_rust_kl_dir> -c a -p gcr.io/project-keylime -t "$GCP_ID" -w
    ```

    where `<path_to_rust_kl_dir>` is the path, relative to your current working directory, to the directory containing the Rust source code for the Keylime agent.

5. Fetch the required plugins for Packer and Terraform:

    ```shell
    packer init . && terraform init
    ```

6. Use Packer to build a VM image in GCP with pre-installed containers for the verifier, registrar, tenant and agent:

    ```shell
    packer build . -var oimgid="$GCP_ID"
    ```

    If an image with that ID already exists, you can overwrite it by adding the `-force` option.

7. Create a new Terraform workspace and instantiate a new VM instance based on the image generated by Packer:

    ```shell
    terraform workspace new <workspace_name>
    terraform apply -var ssh_public_key=<pub_key_path> -var image_name="packer-keylime-$GCP_ID" -var ovmid="$GCP_ID"
    ```

    where `<workspace_name>` is a name of your choice, only visible to you, to represent the environment you are deploying (e.g., "development" or "staging") and `<pub_key_path>` is the path to your SSH public key (usually beginning with `~/.ssh`).

### Result

If you have performed the above steps in order, you will now see the following resources in the GCP console:

- In the [GCP Container Registry](https://console.cloud.google.com/gcr/images/project-keylime?project=project-keylime):

  - A Docker image in the `keylime_base` repository with the tag `<GCP_ID>`.
  - A Docker image in the `keylime_verifier` repository with the tag `<GCP_ID>`.
  - A Docker image in the `keylime_registrar` repository with the tag `<GCP_ID>`.
  - A Docker image in the `keylime_tenant` repository with the tag `<GCP_ID>`.
  - A Docker image in the `keylime_agent` repository with the tag `<GCP_ID>`.

- In GCP Compute Engine, under [Images](https://console.cloud.google.com/compute/images?tab=images&project=project-keylime):

  - A VM image called `packer-keylime-<GCP_ID>`.

- In GCP Compute Engine, under [VM Instances](https://console.cloud.google.com/compute/instances?project=project-keylime):

  - A VM instance called `terraform-keylime-<GCP_ID>` which will be assigned the IP address output by Terraform in step 7. Note that this IP is dynamic so it will change upon VM reboot.

You can access the VM with SSH:

```shell
ssh kluser@<ip>
```

where `<ip>` is the IP address of the VM.

Now if you run `docker ps` in the remote shell, you will see running containers for each Keylime component (named `keylime_verifier`, `keylime_registrar`, `keylime_tenant` and `keylime_agent`). Keylime data and configuration files are stored in Docker volumes named `kl-data-vol` and `kl-config-vol` respectively. You can use `docker volume inspect <vol_name>` to find the mount point of these volumes.

To access a shell inside a container, use Docker's `exec` command. For example, to use the Keylime tenant to check the status of the deployment:

```console
[kluser@terraform-keylime]$ docker exec -it keylime_tenant /bin/bash
[root@7fbd2d3c6f52 /]# keylime_tenant status
```

Finally, if you wish to see the log output of one of the Keylime components, run `docker logs <container_name>`.

## Reference Documentation

### kl-deploy-images.sh

Supports building Dockers images for the specified Keylime components using source code obtained from various locations. Running `kl-deploy-images.sh -h` gives a listing of options and usage examples:

```
Builds Keylime Docker images locally and optionally pushes them to GCR.

Usage: kl-deploy-images.sh <components> [opts...]

Options:
-r <repo>       : the URL to the remote Git repo containing the source
-b <branch>     : the name of the branch to check out (default: "master")
-d <dir>        : the path to the Keylime source directory (default: "./keylime")
-c <components> : a string indicating which Keylime components to build from the source directory; use "v" for the verifier, "r" for the registrar, "t" for the tenant, "a" for the agent, or combine these characters to build multiple components (default: "vrt").
-t <tag>        : a tag to apply to the built images (defaults to the current timestamp)
-p <registry>   : the Docker registry to push the images to
-w              : write variable files to working directory to make image tags available to Packer (ignored unless -p is used)
-h              : display help text

Examples:

kl-deploy-images.sh -r git@github.com:keylime/keylime.git -p gcr.io/project-keylime
  Retrieves Keylime source code, builds verifier, registrar and tenant images and pushes these to GCR.

kl-deploy-images.sh -r git@github.com:keylime/rust-keylime.git -d ./rust-keylime -c a -p gcr.io/project-keylime
  Retrieves source code for the Rust agent, builds a Docker image and pushes it to GCR.

kl-deploy-images.sh -r git@github.com:hse-aurora/keylime.git -b develop -c vt
  Retrieves the develop branch of the internal Keylime repo and only builds Docker images for the verifier and tenant.

kl-deploy-images.sh -d ~/keylime -c t -p gcr.io/project-keylime
  Builds an image for the tenant from a specific source directory and pushes it to GCR.
```

### kl-gce-image.pkr.hcl

This configuration file can be used with Packer to create a new VM image in GCP by performing the following tasks in a temporary VM which is destroyed upon completion:

1. Installs Docker.
2. Installs the Docker credential helper provided by GCP to allow Docker to authenticate to GCR using the default service account associated with the VM.
3. Pulls Docker images for the Keylime verifier, registrar, tenant and agent from GCR.
4. Creates and starts containers from the images with the appropriate port and file system mappings so that each Keylime component has access to the needed data and configuration files and can communicate with one another.

To use the file, fetch the necessary Packer plugins with the `init` command and then run Packer with the following options:

```shell
packer init .
packer build -var vrt_tag=<vrt_tag> -var a_tag=<a_tag> -var oimgid=<id> kl-gce-image.pkr.hcl
```

This will use the container images for the verifier, registrar and tenant in GCR which have the tag of `<vrt_tag>` and the image for the agent with the `<a_tag>` tag. If the kl-deploy-images.sh script has previously been run with the `-w` option, you can drop the options to specify the `vrt_tag` and `a_tag` variables in which case the dynamic tag values found in the `variables-*.auto.pkrvars.hcl` files generated by the script will be used instead.

A VM image will be generated in GCP with the name `packer-keylime-<id>`. If you don't provide an output image ID by setting the `oimgid` variable, the current timestamp will be used.

### kl-gce-vm.tf

To use this file to instantiate a new VM in GCP from an image created by Packer, first initialise the directory:

```shell
terraform init
```

Then, create a new workspace which corresponds to the environment you are deploying (e.g., "development", "staging", etc.):

```shell
terraform workspace new staging
```

You can list your available workspaces with the `terraform workspace list` command and switch between them with the `terraform workspace select <name>` command.

Now, you can use this command to create a new VM:

```shell
terraform apply -var ssh_public_key=<pub_key_path> -var image_name=<img_name> -ovmid=<id>
```

where `<pub_key_path>` is the path to your SSH public key file (e.g., `~/.ssh/id_ed25519.pub`) and `<img_name>` is the name of the image from which to instantiate the VM (starting with `packer-keylime-...`).

The new VM will have the name of `terraform-keylime-<id>`. If you don't provide an output VM ID by setting the `ovmid` variable, the current timestamp will be used.

To delete the VM, use the `terraform destroy` command.

## Future Evolutions

**kl-deploy-images.sh**:

- The script currently uses the Dockerfiles provided by the Keylime project unmodified. These are based on the official Fedora image but we like to swap this out for a distro-less image from Chainguard. This will require work beyond just changing the base image to ensure all dependencies are met, so this hasn't been realised in this iteration but should be possible to implement in the near term.
- Currently, to configure Keylime's network settings, the script appends instructions to the end of the Keylime-provided Dockerfiles. These instructions consist of a number of find and replace operations (using `sed`) to modify the config files generated by the official installer script. While this works, it may be needlessly complex and possibly brittle. An alternative approach would be to modify the `mapping.json` file (perhaps using `jq`) used to generate the config files prior to building the Docker images which would at least be one less level of indirection. We should consider adopting this or a different mechanism for configuring Keylime.
- If an effort is launched to rewrite some or all of the Keylime components currently implemented in Python, the script should mostly work as is if the correct options are passed in, although, the hard-coded paths at which to find the Dockerfiles will likely need to be updated.

## Contribution Guidelines

If you wish to make changes to the kl-deploy-images.sh shell script, please check them against [ShellCheck](https://www.shellcheck.net/) before committing.