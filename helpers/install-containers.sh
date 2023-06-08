#!/usr/bin/env bash

set -e

if [[ -z "$VRT_TAG" || -z "$A_TAG" ]]; then
  echo "Environment variables VRT_TAG and A_TAG must be set" >&2
  exit 1
fi

# Install Docker
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

# Install the GCP credential helper for Docker to automatically retrieve the credentials of the service account associated with the GCE instance so that pulling images from GCR will succeed
curl -fsSL https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.6/docker-credential-gcr_linux_amd64-2.1.6.tar.gz | tar xz docker-credential-gcr
chmod +x docker-credential-gcr
sudo mv docker-credential-gcr /usr/bin/
sudo docker-credential-gcr configure-docker

# Pull Keylime Docker images from GCR
sudo docker pull "gcr.io/project-keylime/keylime_verifier:$VRT_TAG"
sudo docker pull "gcr.io/project-keylime/keylime_registrar:$VRT_TAG"
sudo docker pull "gcr.io/project-keylime/keylime_tenant:$VRT_TAG"
sudo docker pull "gcr.io/project-keylime/keylime_agent:$A_TAG"

# Create custom network bridge to allow containers to communicate with one another by name instead of IP address
sudo docker network create keylime-net

# Create containers from the images with the appropriate mappings to allow sharing of data between containers
verifier_id=$(sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime -v kl-vrt-src-vol:/usr/local/src/keylime --net keylime-net -p 8880:8880 -p 8881:8881 --restart unless-stopped --name keylime_verifier "gcr.io/project-keylime/keylime_verifier:$VRT_TAG")
registrar_id=$(sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime -v kl-vrt-src-vol:/usr/local/src/keylime --net keylime-net -p 8890:8890 -p 8891:8891 --restart unless-stopped --name keylime_registrar "gcr.io/project-keylime/keylime_registrar:$VRT_TAG")
sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime -v kl-vrt-src-vol:/usr/local/src/keylime --net keylime-net --restart unless-stopped --entrypoint /bin/bash --name keylime_tenant "gcr.io/project-keylime/keylime_tenant:$VRT_TAG"

# Wait up to 30s for verifier and registrar to start
count=0
while ! docker top "$verifier_id" &> /dev/null || ! docker top "$registrar_id" &> /dev/null; do
  sleep 1
  let "count++"

  [[ $count -ge 30 ]] && break
done

sudo docker run -itd -v kl-data-vol:/var/lib/keylime -v kl-a-config-vol:/etc/keylime -v kl-a-src-vol:/usr/local/src/rust-keylime --net keylime-net -p 9002:9002 --restart unless-stopped --tmpfs /var/lib/keylime/secure:size=1024k,mode=0700 --device /dev/tpm0:/dev/tpm0 --device /dev/tpmrm0:/dev/tpmrm0 --name keylime_agent "gcr.io/project-keylime/keylime_agent:$A_TAG"
