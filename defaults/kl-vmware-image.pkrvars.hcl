# base_vmx: The path to the VMX image to use as the base image when building the VM. Whatever image is provided, it
#   must contain a Fedora install and have the OS user "packer" with password "packer" and an entry in the sudoers file
#   to enable passwordless sudo (but only for the "packer" user)
base_vmx = "./vm-templates/keylime-fedora-template/keylime-fedora-template.vmx"

# vrt_tag: The tag applied to the container images which should be retrieved from the container registry for the
#   verifier, registrar and tenant when building the VMWare image
vrt_tag = "latest"

# a_tag: The tag applied to the container image which should be used for the agent when building the VMWare image
a_tag = "latest"

# oimg_label: A label of your choice to apply to VMWare image output by Packer. The resulting VM name and hostname will
#   be "packer-keylime-<oimg_label>". If you include "{{timestamp}}", it will be replaced by the Unix timestamp and
#   the time the image in generated
oimg_label = "{{timestamp}}"

# username: The username to give the OS user account that is created during generation of the VMWare image
username = "kluser"

# ssh_pub: The path to the SSH public key which should be copied to the generated VM to allow access via SSH
ssh_pub = "~/.ssh/id_ed25519.pub"

# gcloud_creds: The path to your gcloud application default credentials JSON file (usually lives in ~/.config/gcloud/
#   application_default_credentials.json or %APPDATA%\gcloud\application_default_credentials.json). If set, your gcloud
#   session will be copied to the VM. If empty, the session will not be copied.
gcloud_creds = ""

# use_swtpm: If true, a container will be installed in the VM with a software TPM emulator. If you turn this off,
#   you will need to encrypt your VM and add a vTPM in VMWare post image creation (not tested).
use_swtpm = true

# use_zscaler: If true, the zscaler root CA will be installed in the VM to allow for corporate traffic inspection
use_zscaler = false

# use_proxy: If true, the hpeautoproxy script is installed in the VM to detect and set corporate proxy settings
use_proxy = false
