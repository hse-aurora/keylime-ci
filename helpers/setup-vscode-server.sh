#!/usr/bin/env bash

# This script queries the GitHub API which returns JSON, so install jq for JSON parsing
sudo dnf -y install jq

# Get path to script for later
script_path=$(realpath "$0")

# Perform all work in a scratch directory
mkdir -p /tmp/vscode-server-install
cd /tmp/vscode-server-install

# When you connect to a remote host with vscode, it will connect to the host over SSH and look for a server program in
# $HOME/.vscode-server/* which matches the current vscode version. This server component consists basically of some
# JavaScript, a copy of the NodeJS executable and a shell script to invoke NodeJS and pass in the appropriate JS file.
# We will patch this shell script to invoke NodeJS with sudo, so that vscode can access directories owned by root.
# However, this is not enough, because if a password is required for sudo, the connection will fail.
#
# Instead of trying to exempt every copy of NodeJS on the system, the following script is added in /usr/local/bin and
# added to the sudoers file to specify that sudo should not prompt for a password when invoking this script. Then, the
# vscode server launch scripts are patched to use this script to start NodeJS.
sudo tee /usr/local/bin/launchvscodesrv > /dev/null <<'EOF'
#!/usr/bin/env bash

case "$1" in
  --inspect*) INSPECT="$1"; shift;;
esac

ROOT="$(dirname "$(dirname "$1")")"

if [[ "$ROOT" != "$HOME"/.vscode-server/bin/* ]]; then
  echo "Path to JS file invalid, exiting." >&2
  exit 1
fi

"$ROOT/node" ${INSPECT:-} "$@"
EOF

sudo chmod 755 /usr/local/bin/launchvscodesrv

if ! sudo grep -q "NOPASSWD: /usr/local/bin/launchvscodesrv" "/etc/sudoers"; then
  echo "%wheel  ALL=(root)      NOPASSWD: /usr/local/bin/launchvscodesrv" | sudo EDITOR="tee -a" visudo > /dev/null
fi

# Fetch a list of recent vscode releases
releases_json=$(curl -fsSL "https://api.github.com/repos/microsoft/vscode/releases")

# Since the vscode server version must match that of the user's local install, perform installs of the last three
# vscode server releases
echo "$releases_json" | jq -r ".[0:3][].tag_name" | while read -r tag_name; do
  # The vscode server is saved in a directory with a name corresponsing to the commit hash for that version of vscode,
  # so retrieve data about the vscode release and traverse the JSON returned to obtain the hash
  tag_json=$(curl -fsSL "https://api.github.com/repos/microsoft/vscode/git/ref/tags/$tag_name")
  tag_object=$(echo "$tag_json" | jq -r ".object")
  object_sha=$(echo "$tag_object" | jq -r ".sha")
  object_type=$(echo "$tag_object" | jq -r ".type")
  object_url=$(echo "$tag_object" | jq -r ".url")

  if [[ "$object_type" == "commit" ]]; then
    sha="$object_sha"
  else
    inner_tag_json=$(curl -fsSL "$object_url")
    sha=$(echo "$inner_tag_json" | jq -r ".object.sha")
  fi

  echo "Downloading VS Code Server version $tag_name (commit: $sha)..."
  
  # Microsoft makes the vscode server bundle available at this URL
  curl -fsSL "https://update.code.visualstudio.com/commit:$sha/server-linux-x64/stable" -o "$sha.tar.gz"

  # Install the vscode server in the /etc/skel directory so that it will get copied into the home directory for all
  # users which are subsequently created
  sudo rm -rf "/etc/skel/.vscode-server/bin/$sha"
  sudo mkdir -p "/etc/skel/.vscode-server/bin/$sha"
  sudo tar -xzf "$sha.tar.gz" -C "/etc/skel/.vscode-server/bin/$sha" --strip 1
  sudo touch "/etc/skel/.vscode-server/bin/$sha/0"

  # Edit initialising script to run Node using sudo (via launchvscodesrv) when starting the server
  # sudo sed -i 's/^\"\$ROOT\/node\"/sudo launchvscodesrv/' "/etc/skel/.vscode-server/bin/$sha/server.sh"
  sudo sed -i 's/^\"\$ROOT\/node\"/sudo launchvscodesrv/' "/etc/skel/.vscode-server/bin/$sha/bin/code-server"

  # Copy vscode server files with modifications into the current user's home directory
  sudo cp -r /etc/skel/.vscode-server "$HOME/.vscode-server"
done

# When a home directory is created for a new user, the contents of /etc/skel are copied into that new home directory
# and the ownership of those files are assigned to the new user. This is a security issue in our case, because a
# non-privilleged process could edit the vscode server scripts in the user's home directory to run arbitrary code
# as root since they invoke launchvscodesrv.
#
# The following script is added to /etc/shadow-maint/useradd-post.d so that it can set ownership of these files to root
# after a user is created. Since launchvscodesrv only accepts JS files from the $HOME/.vscode-server/ directory, it
# should not be possible for a process to use it to run aribtrary code unless that process is already running as root.
sudo mkdir -p /etc/shadow-maint/useradd-post.d
sudo tee /etc/shadow-maint/useradd-post.d/setvscodesrvown.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
eval subject_home="~$SUBJECT"
chown -R root:root "$subject_home/.vscode-server/"
EOF
sudo chmod 755 /etc/shadow-maint/useradd-post.d/setvscodesrvown.sh

# Copy this setup script into /usr/local/bin so that the user can use it to download and install new versions of the
# vscode server as they become available.
sudo cp -r "$script_path" /usr/local/bin/installvscodesrv

# Clean up
rm -r /tmp/vscode-server-install