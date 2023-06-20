#!/usr/bin/env bash

set -e

# Create links to source volumes in the standard system source code directory
sudo ln -s "/var/lib/docker/volumes/kl-vrt-src-vol/_data" "/usr/local/src/keylime"
sudo ln -s "/var/lib/docker/volumes/kl-a-src-vol/_data" "/usr/local/src/rust-keylime"

# Create links to config volumes in /etc
sudo ln -s "/var/lib/docker/volumes/kl-vrt-config-vol/_data" "/etc/keylime"
sudo ln -s "/var/lib/docker/volumes/kl-a-config-vol/_data" "/etc/rust-keylime"

# Create link to the shared data volume at the default location expected by Keylime
sudo ln -s "/var/lib/docker/volumes/kl-data-vol/_data" "/var/lib/keylime"


# As a convenience, when using vscode remote coding, create links in the root home directory also...

sudo ln -s "/usr/local/src/keylime" "/root/keylime"
sudo ln -s "/usr/local/src/rust-keylime" "/root/rust-keylime"

sudo mkdir -p "/root/.config"
sudo ln -s "/etc/keylime" "/root/.config/keylime"
sudo ln -s "/etc/rust-keylime" "/root/.config/rust-keylime"

sudo ln -s "/var/lib/keylime" "/root/.kl-data"
