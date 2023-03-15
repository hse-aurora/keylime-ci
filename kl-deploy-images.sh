#!/usr/bin/env bash 

help () {
  echo "Builds Keylime Docker images locally and optionally pushes them to GCR."
  echo ""
  echo "Usage: kl-deploy-images.sh <components> [opts...]"
  echo ""
  echo "Options:"
  echo "-r <repo>       : the URL to the remote Git repo containing the source"
  echo "-b <branch>     : the name of the branch to check out (default: \"master\")"
  echo "-d <dir>        : the path to the Keylime source directory (default: \"./keylime\")"
  echo "-c <components> : a string indicating which Keylime components to build from the source directory; use \"r\" for the registrar, \"v\" for the verifier, \"t\" for the tenant, \"a\" for the agent, or combine these characters to build multiple components (default: \"rvt\")."
  echo "-p <registry>   : the Docker registry to push the images to"
  echo "-h              : display help text"
  echo ""
  echo "Examples:"
  echo ""
  echo "kl-deploy-images.sh -r git@github.com:keylime/keylime.git -p gcr.io/project-keylime"
  echo "  Retrieves Keylime source code, builds registrar, verifier and tenant images and pushes these to GCR."
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

comp_str="rvt"
branch="master"
src_dir="./keylime"

while getopts r:b:d:c:p:h opt; do
  case "$opt" in
    r) repo="${OPTARG}" ;;
    b) branch="${OPTARG}" ;;
    d) src_dir="${OPTARG}" ;;
    c) comp_str="${OPTARG}" ;;
    p) registry="${OPTARG}" ;;
    h) help
       exit 0 ;;
    *) # illegal option: getopts will output an error
       echo "" >&2
       help >&2
       exit 1
  esac
done

comp_arr=()

if [[ "$comp_str" =~ [rvt]{1,} ]]; then
  comp_arr+=("base")
fi

for (( i=0; i<${#comp_str}; i++ )); do
  case "${comp_str:$i:1}" in
    "r") comp_arr+=("registrar") ;;
    "v") comp_arr+=("verifier") ;;
    "t") comp_arr+=("tenant") ;;
    "a") comp_arr+=("agent") ;;
    *) echo "Invalid components string. Must only contain characters \"r\", \"v\", \"t\" and \"a\"." >&2
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

# Generate Dockerfiles from .in template files if registrar, verifier or tenant images are being built
if [[ "$comp_str" =~ [rvt]{1,} ]]; then
  echo "🡆 Generating Dockerfiles from template files..."
  owd=$(pwd)
  cd "$src_dir/docker/release" || exit
  ./generate-files.sh "$branch"
  cd "$owd" || exit
fi

# Build Docker images from Dockerfiles
echo "🡆 Building Docker images from Dockerfiles..."
for part in ${comp_arr[@]}; do
  image_name="keylime_$part:$branch"

  echo "Building $image_name..."

  if [[ "$comp_str" =~ [rvt]{1,} ]]; then
    docker build -t "$image_name" -f "$src_dir/docker/release/$part/Dockerfile" "$src_dir"
  fi

  if [[ "$comp_str" =~ a ]]; then
    docker build -t "$image_name" -f "$src_dir/docker/fedora/keylime_rust.Dockerfile" "$src_dir/docker/fedora"
  fi
done

# If a container registry has been provided, push Docker images to the registry
if [ -n "$registry" ]; then
  echo "🡆 Uploading Docker images to the container registry at $registry..."
  for part in ${comp_arr[@]}; do
    image_name="keylime_$part:$branch"
    registry_image_path="$registry/$image_name"

    echo "Pushing $image_name to $registry_image_path..."
    docker tag "$image_name" "$registry_image_path"
    docker push "$registry_image_path" || { echo "Authentication failed! Your GCP session may have expired (run \`gcloud auth login\` to fix) or Docker may not be configured to use gcloud as an authentication provider (try \`gcloud auth configure-docker\`)." >&2; exit; }
  done
else
  echo "🡆 No container registry has been provided, so skipping push to registry."
fi