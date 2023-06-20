# Keylime CI

This repo contains various automation tools to support the development and testing of [Keylime](https://keylime.dev/) using [Packer](https://www.hashicorp.com/products/packer), [Terraform](https://www.terraform.io/) and [GitHub Actions](https://docs.github.com/en/actions).

Guides for common tasks are given below.

### I want to...

- [**Set up a New Containerised Development Environment**](docs/dev-env.md)
- [**Deploy a Keylime Installation to Google Cloud Platform (GCP)**](docs/gcloud-deploy.md)
- [**Automate Staging Environment Deployment with GCP and GitHub Actions**](docs/staging-env.md)

## Directory Structure

The main files of this repo are:

- **kl-deploy-images.sh** ([docs](docs/kl-deploy-images.sh.md)): Bash script which retrieves Keylime source code, builds Docker images for the various Keylime components (the registrar, verifier, tenant and agent), and pushes the images to the GCP container registry.
- **kl-vmware-image.pkr.hcl** ([docs](docs/kl-vmware-image.pkr.hcl.md)): Packer configuration file for standing up batteries-included containerised developer environments in VMWare.
- **kl-gce-image.pkr.hcl** ([docs](docs/kl-gce-image.pkr.hcl.md)): Packer configuration file for building VM images for GCP Compute Engine with containers for each of the Keylime components.
- **kl-gce-vm.tf** ([docs](docs/kl-gce-vm.tf.md)): Terraform configuration file for instantiating a VM in GCP from an image built by Packer.

Dockerfiles for each of the Keylime components can be found in the [`docker`](docker) directory.

Supporting shell scripts used by the Packer config files are in the [`helpers`](helpers) directory. Default Packer/Terraform input variable values are in [`defaults`](defaults).

## Future Efforts

- Improve docs.
- Switch to Dockerfiles based on distroless images (e.g., see [this PR](https://github.com/keylime/rust-keylime/pull/601).)
- Use Packer templates to modularise the current Packer config files and improve flexibility for a wider variety of use cases.

## Contribution Guidelines

PRs welcome. If you wish to make changes to any of shell scripts in the repo, please check them against [ShellCheck](https://www.shellcheck.net/).