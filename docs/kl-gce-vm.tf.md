# GCE VM Builder (kl-gce-vm.tf)

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
terraform apply -var image_name=<img_name> -ovmid=<id>
```

where `<img_name>` is the name of the image from which to instantiate the VM (starting with `packer-keylime-...`).

If you wish to specify a public key to add to the VM for SSH access, you can set the `ssh_public_key` input variable to the path where your SSH public key file (e.g., `~/.ssh/id_ed25519.pub`) is located. Otherwise, Terraform will output a gcloud command you can use to connect to the VM over SSH instead.

The new VM will have the name of `terraform-keylime-<id>`. If you don't provide an output VM ID by setting the `ovmid` variable, the current timestamp will be used.

To delete the VM, use the `terraform destroy` command.