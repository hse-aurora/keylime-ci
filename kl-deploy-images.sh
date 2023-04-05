#!/usr/bin/env bash
# shellcheck disable=SC2129

help () {
  echo "Builds Keylime Docker images locally and optionally pushes them to GCR."
  echo ""
  echo "Usage: kl-deploy-images.sh <components> [opts...]"
  echo ""
  echo "Options:"
  echo "-r <repo>       : the URL to the remote Git repo containing the source"
  echo "-b <branch>     : the name of the branch to check out (default: \"master\")"
  echo "-d <dir>        : the path to the Keylime source directory (default: \"./keylime\")"
  echo "-c <components> : a string indicating which Keylime components to build from the source directory; use \"v\" for the verifier, \"r\" for the registrar, \"t\" for the tenant, \"a\" for the agent, or combine these characters to build multiple components (default: \"vrt\")."
  echo "-t <tag>        : a tag to apply to the built images (defaults to the current timestamp)"
  echo "-p <registry>   : the Docker registry to push the images to"
  echo "-w              : write variable files to working directory to make image tags available to Packer (ignored unless -p is used)"
  echo "-h              : display help text"
  echo ""
  echo "Examples:"
  echo ""
  echo "kl-deploy-images.sh -r git@github.com:keylime/keylime.git -p gcr.io/project-keylime"
  echo "  Retrieves Keylime source code, builds verifier, registrar and tenant images and pushes these to GCR."
  echo ""
  echo "kl-deploy-images.sh -r git@github.com:keylime/rust-keylime.git -d ./rust-keylime -c a -p gcr.io/project-keylime"
  echo "  Retrieves source code for the Rust agent, builds a Docker image and pushes it to GCR."
  echo ""
  echo "kl-deploy-images.sh -r git@github.com:hse-aurora/keylime.git -b develop -c vt"
  echo "  Retrieves the develop branch of the internal Keylime repo and only builds Docker images for the verifier and tenant."
  echo ""
  echo "kl-deploy-images.sh -d ~/keylime -c t -p gcr.io/project-keylime"
  echo "  Builds an image for the tenant from a specific source directory and pushes it to GCR."
}

comp_str="vrt"
branch="master"
src_dir="./keylime"
tag=$(date +%s)
write_vars=false

while getopts r:b:d:c:t:p:wh opt; do
  case "$opt" in
    r) repo="${OPTARG}" ;;
    b) branch="${OPTARG}" ;;
    d) src_dir="${OPTARG}" ;;
    c) comp_str="${OPTARG}" ;;
    t) tag="${OPTARG}" ;;
    p) registry="${OPTARG}" ;;
    w) write_vars=true ;;
    h) help
       exit 0 ;;
    *) # illegal option: getopts will output an error
       echo "" >&2
       help >&2
       exit 1
  esac
done

comp_arr=()

if [[ "$comp_str" =~ [vrt]{1,} ]]; then
  comp_arr+=("base")
fi

for (( i=0; i<${#comp_str}; i++ )); do
  case "${comp_str:$i:1}" in
    "v") comp_arr+=("verifier") ;;
    "r") comp_arr+=("registrar") ;;
    "t") comp_arr+=("tenant") ;;
    "a") comp_arr+=("agent") ;;
    *) echo "Invalid components string. Must only contain characters \"v\", \"r\", \"t\" and \"a\"." >&2
      echo "" >&2
      help >&2
      exit 1
  esac
done

# If no repo has been provided and the source directory doesn't exist or is empty, display an error message
if [ -z "$repo" ] && { [ ! -d "$src_dir" ] || [ ! "$(ls -A "$src_dir")" ]; }; then
  echo "You must specify the location in which the Keylime source code can be found. Either use options -r and -b to specify a remote Git repo to use, or ensure that the source directory (specified using -d) exists and is not empty." >&2
  exit 1
fi

# If a repo has been provided but the source directory already contains source files, display an error message
if [ -n "$repo" ] && [ -d "$src_dir" ] && [ "$(ls -A "$src_dir")" ]; then
  echo "You've provided a remote repo to fetch source code from, but the source code directory ($src_dir) already exists and is not empty. Either drop the -r option to use the existing source in $src_dir, or use -d to specify a different source directory." >&2
  exit 1
fi

# If a repo has been provided, clone that repo into the source directory
if [ -n "$repo" ]; then
  echo "🡆 Cloning $branch branch from repo $repo into $src_dir..."
  git clone -b "$branch" "$repo" "$src_dir"
else
  echo "🡆 No repo has been provided, so skipping clone and using the contents of $src_dir."
fi

# TODO: Modify Keylime's templated Dockerfiles to use Chainguard images.
# Note from Dat:
###
# if you want to change the base image of the containers
# try using sed to replace the Docker.in files
# example: sed -i "s/fedora:37/rockylinux:9/g" keylime/docker/release/base/Dockerfile.in
###

# Perform actions on Keylime's templated Dockerfiles if verifier, registrar or tenant images are being built...
if [[ "$comp_str" =~ [vrt]{1,} ]]; then
  # Change to directory containing templates but remember current working directory
  owd=$(pwd)
  cd "$src_dir/docker/release" || exit

  # Generate Dockerfiles from .in template files
  echo "🡆 Generating Dockerfiles from template files..."
  ./generate-files.sh "$tag"

  echo "🡆 Extending Dockerfiles to modify the default Keylime network config..."

  # Add instructions to base Dockerfile to modify verifier.conf with the correct network settings
  echo "" >> base/Dockerfile
  echo "RUN sed -i \"s/^ip = 127.0.0.1$/ip = 0.0.0.0/\" /etc/keylime/verifier.conf && \\" >> base/Dockerfile
  echo "    sed -i \"s/^registrar_ip = 127.0.0.1$/registrar_ip = keylime_registrar/\" /etc/keylime/verifier.conf && \\" >> base/Dockerfile
  echo "    sed -i \"s/^registrar_port = 8881$/registrar_port = 8891/\" /etc/keylime/verifier.conf" >> base/Dockerfile

  # Add instructions to base Dockerfile to modify registrar.conf with the correct network settings
  echo "" >> base/Dockerfile
  echo "RUN sed -i \"s/^ip = 127.0.0.1$/ip = 0.0.0.0/\" /etc/keylime/registrar.conf" >> base/Dockerfile

  # Add instructions to base Dockerfile to modify tenant.conf with the correct network settings
  echo "" >> base/Dockerfile
  echo "RUN sed -i \"s/^verifier_ip = 127.0.0.1$/verifier_ip = keylime_verifier/\" /etc/keylime/tenant.conf && \\" >> base/Dockerfile
  echo "    sed -i \"s/^registrar_ip = 127.0.0.1$/registrar_ip = keylime_registrar/\" /etc/keylime/tenant.conf" >> base/Dockerfile

  # Add instructions to base Dockerfile to set appropriate permissions for data directory
  echo "" >> base/Dockerfile
  echo "RUN useradd keylime && usermod -a -G tss keylime && \\" >> base/Dockerfile
  echo "    timeout --preserve-status 30s keylime_verifier && \\" >> base/Dockerfile # run keylime_verifier to create cv_ca directory containing certs
  echo "    chown -R keylime:tss /var/lib/keylime/"  >> base/Dockerfile # change ownership of keylime directory and children including cv_ca directory

  # Add instructions to base Dockerfile to expose data and config directories as volumes
  echo "" >> base/Dockerfile
  echo "VOLUME /etc/keylime" >> base/Dockerfile
  echo "VOLUME /var/lib/keylime" >> base/Dockerfile

  # Change back to previous working directory
  cd "$owd" || exit
fi

# Build Docker images from Dockerfiles
echo "🡆 Building Docker images from Dockerfiles..."
for part in "${comp_arr[@]}"; do
  image_name="keylime_$part:$tag"

  echo "Building $image_name..."

  if [[ "$comp_str" =~ [vrt]{1,} ]]; then
    DOCKER_BUILDKIT=1 docker build -t "$image_name" -f "$src_dir/docker/release/$part/Dockerfile" "$src_dir"
  fi

  if [[ "$comp_str" =~ a ]]; then
    DOCKER_BUILDKIT=1 docker build -t "$image_name" -f "docker/agent.Dockerfile" "$src_dir"
  fi
done

# If a container registry has been provided, push Docker images to the registry
if [ -n "$registry" ]; then
  echo "🡆 Uploading Docker images to the container registry at $registry..."
  for part in "${comp_arr[@]}"; do
    image_name="keylime_$part:$tag"
    registry_image_path="$registry/$image_name"

    echo "Pushing $image_name to $registry_image_path..."
    docker tag "$image_name" "$registry_image_path"
    docker push "$registry_image_path" || { echo "\`docker push\` command failed! This may be an authentication issue: your GCP session may have expired (run \`gcloud auth login\` to fix) or Docker may not be configured to use gcloud as an authentication provider (try \`gcloud auth configure-docker\`)." >&2; exit 1; }
  done

  # If option is turned on, output variable files to provide Packer with the identifying tag applied to the images
  if [ "$write_vars" = true ]; then

    if [[ "$comp_str" =~ [vrt]{1,} ]]; then
      echo "vrt_tag = \"$tag\"" > variables-vrt.auto.pkrvars.hcl
      echo "Writen tag name ($tag) to variables-vrt.auto.pkrvars.hcl."
    fi

    if [[ "$comp_str" =~ a ]]; then
      echo "a_tag = \"$tag\"" > variables-a.auto.pkrvars.hcl
      echo "Writen tag name ($tag) to variables-a.auto.pkrvars.hcl."
    fi
  fi
else
  echo "🡆 No container registry has been provided, so skipping push to registry."
fi