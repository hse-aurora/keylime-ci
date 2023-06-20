# GCE Image Builder (kl-gce-image.pkr.hcl)

This configuration file can be used with Packer to create a new VM image in GCP by performing the following tasks in a temporary VM which is destroyed upon completion:

1. Installs Docker.
2. Installs the Docker credential helper provided by GCP to allow Docker to authenticate to GCR using the default service account associated with the VM.
3. Pulls Docker images for the Keylime verifier, registrar, tenant and agent from GCR.
4. Creates and starts containers from the images with the appropriate port and file system mappings so that each Keylime component has access to the needed data and configuration files and can communicate with one another.

To use the file, fetch the necessary Packer plugins with the `init` command and then run Packer with the following options:

```shell
packer init kl-gce-image.pkr.hcl
packer build -var vrt_tag=<vrt_tag> -var a_tag=<a_tag> -var oimgid=<id> .
```

This will use the container images for the verifier, registrar and tenant in GCR which have the tag of `<vrt_tag>` and the image for the agent with the `<a_tag>` tag. If the kl-deploy-images.sh script has previously been run with the `-w` option, you can drop the options to specify the `vrt_tag` and `a_tag` variables in which case the dynamic tag values found in the `variables-*.auto.pkrvars.hcl` files generated by the script will be used instead.

A VM image will be generated in GCP with the name `packer-keylime-<id>`. If you don't provide an output image ID by setting the `oimgid` variable, the current timestamp will be used.