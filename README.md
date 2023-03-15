# Keylime CI

This repo contains files to support continuous integration of Keylime in GCP. The key components are:

- **kl-deploy-images.sh**: Bash script which retrieves Keylime source code, builds Docker images for the various Keylime components (the registrar, verifier, tenant and agent), and pushes the images to the GCP container registry. (Done)
- **kl-gce-image.pkr.hcl**: [Packer](https://www.hashicorp.com/products/packer) configuration file for building VM images for GCP Compute Engine with containers for each of the Keylime components. (WIP)
- **kl-gce-vm.tf**: [Terraform](https://www.terraform.io/) configuration file for instantiating a VM from an image built by Packer. (WIP)

These have been designed to automate tasks with GitHub Actions, but can also be run locally to quickly spin up extra development or testing environments.

## kl-deploy-images.sh

Supports building Dockers images for the specified Keylime components using source code obtained from various locations. Run `kl-deploy-images.sh -h` to get a full list of options and usage examples.

### Requirements

These dependencies need to be available to use the script:

- [Docker Engine](https://docs.docker.com/engine/) or [Docker Desktop](https://docs.docker.com/desktop/)
- the [gcloud](https://cloud.google.com/sdk/gcloud) CLI (if you wish to push images to GCR)
- Git (if you wish to retrieve source code from a remote Git repo)

Additionally, to push images to GCR, you need to authenticate to gcloud by running `gcloud auth login` and set up Docker to use gcloud as an authentication provider by running `gcloud auth configure-docker` (you can accept the default options).

### Future evolutions

- The script currently uses the Docker images provided by the Keylime project unmodified. These are based on the official Fedora image but we like to swap this out for a distro-less image from Chainguard. This will require work beyond just changing the base image to ensure all dependencies are met, so this hasn't been realised in this iteration but should be possible to implement in the near term.
- If an effort is launched to rewrite some or all of the Keylime components currently implemented in Python, the script should mostly work as is if the correct options are passed in, although, the hard-coded paths at which to find the Dockerfiles will likely need to be updated.