# Keylime CI

This repo contains files to support continuous integration of Keylime in GCP. The key components are:

- **kl-deploy-images.sh**: Bash script which retrieves Keylime source code, builds Docker images for the various Keylime components (the registrar, verifier, tenant and agent), and pushes the images to the GCP container registry.
- **kl-gce-image.pkr.hcl**: [Packer](https://www.hashicorp.com/products/packer) configuration file for building VM images for GCP Compute Engine with containers for each of the Keylime components.
- **kl-gce-vm.tf**: [Terraform](https://www.terraform.io/) configuration file for instantiating a VM from an image built by Packer.

These have been designed to automate tasks with GitHub Actions, but can also be run locally to quickly spin up extra development or testing environments.

## Prerequisite: Authenticating to GCP

Since the files and scripts in this repo all perform actions on GCP, it is a requirement for all of them to properly authenticate using the [gcloud](https://cloud.google.com/sdk/gcloud) CLI. As alternative, when these files are employed in a GitHub Actions workflow, the [auth action](https://github.com/google-github-actions/auth) can be used instead.

To authenticate using the gcloud CLI, make sure the CLI is installed and then run `gcloud auth login`.

## kl-deploy-images.sh

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

### Requirements

These dependencies need to be available to use the script:

- [Docker Engine](https://docs.docker.com/engine/) or [Docker Desktop](https://docs.docker.com/desktop/)
- Git (if you wish to retrieve source code from a remote Git repo)

Additionally, to push images to GCR, you need to set up Docker to use gcloud as an authentication provider by running `gcloud auth configure-docker` (you can accept the default options).

### Future evolutions

- The script currently uses the Dockerfiles provided by the Keylime project unmodified. These are based on the official Fedora image but we like to swap this out for a distro-less image from Chainguard. This will require work beyond just changing the base image to ensure all dependencies are met, so this hasn't been realised in this iteration but should be possible to implement in the near term.
- Currently, to configure Keylime's network settings, the script appends instructions to the end of the Keylime-provided Dockerfiles. These instructions consist of a number of find and replace operations (using `sed`) to modify the config files generated by the official installer script. While this works, it may be needlessly complex and possibly brittle. An alternative approach would be to modify the `mapping.json` file (perhaps using `jq`) used to generate the config files prior to building the Docker images which would at least be one less level of indirection. We should consider adopting this or a different mechanism for configuring Keylime.
- If an effort is launched to rewrite some or all of the Keylime components currently implemented in Python, the script should mostly work as is if the correct options are passed in, although, the hard-coded paths at which to find the Dockerfiles will likely need to be updated.

## kl-gce-image.pkr.hcl

This configuration file can be used with Packer to create a new VM image in GCP by performing the following tasks in a temporary VM which is destroyed upon completion:

1. Install Docker.
2. Install the Docker credential helper provided by GCP to allow Docker to authenticate to GCR using the default service account associated with the VM.
3. Pull Docker images for the Keylime verifier, registrar, tenant and agent from GCR.
4. Create and start containers from the images with the appropriate port and file system mappings so that each Keylime component has access to the needed data and configuration files and can communicate with one another.

To use the file, fetch the necessary Packer plugins with the `init` command and then simply pass the file path to the Packer executable:

```
packer init .
packer build kl-gce-image.pkr.hcl
```

By default, this will use the container images for the verifier, registrar, tenant and agent in GCR which have the tag `master`. If the kl-deploy-images.sh script has previously been run, then the dynamic tag values found in the `variables-*.auto.pkrvars.hcl` files generated by the script will be used instead. You can also override these by specifying the tags on the command line: `packer build kl-gce-image.pkr.hcl -var vrt_tag=v6.7.0 -var a_tag=develop` (the verifier, registrar and tenant are assumed to share the same tag).

A VM image will be generated in GCP with the name "packer-keylime-\<ID>" where, by default, \<ID> is the current timestamp. You can also specify this output image ID by setting the `oimgid` variable: `packer build kl-gce-image.pkr.hcl -var oimgid=dev`.

## kl-gce-vm.tf

To use this file to instantiate a new VM in GCP from an image created by Packer, first initialise the directory:

```
terraform init
```

Then, create a new workspace which corresponds to the environment you are deploying (e.g., "development", "staging", etc.):

```
terraform workspace new staging
```

You can list your available workspaces with the `terraform workspace list` command and switch between them with the `terraform workspace select <name>` command.

Now, you can use this command to create a new VM:

```
terraform apply -var ssh_public_key=<PUB_K_PATH> -var image_name=<IMG_NAME>
```

where \<PUB_K_PATH> is the path to your SSH public key file (e.g., `~/.ssh/id_ed25519.pub`) and \<IMG_NAME> is the name of the image from which to instantiate the VM (e.g., `packer-keylime-1679432276`).

The new VM will have the name of "keylime-<WORKSPACE>" where \<WORKSPACE> is the name of the workspace. To delete the VM, use the `terraform destroy` command.

## Contributing

If you wish to make changes to the kl-deploy-images.sh shell script, please check them against [ShellCheck](https://www.shellcheck.net/) before committing.