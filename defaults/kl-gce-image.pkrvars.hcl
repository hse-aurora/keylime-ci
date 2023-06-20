# vrt_tag: The tag applied to the container images which should be retrieved from the container registry for the
#   verifier, registrar and tenant when building the VMWare image
vrt_tag = "latest"

# a_tag: The tag applied to the container image which should be used for the agent when building the VMWare image
a_tag = "latest"

# oimgid: A label of your choice to apply to VMWare image output by Packer. The resulting VM name and hostname will
#   be "packer-keylime-<oimgid>". If you include "{{timestamp}}", it will be replaced by the Unix timestamp and
#   the time the image in generated
oimgid = "{{timestamp}}"