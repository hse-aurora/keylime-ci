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

# Build Docker images from Dockerfiles
echo "🡆 Building Docker images from Dockerfiles..."
for part in "${comp_arr[@]}"; do
  image_name="keylime_$part:$tag"

  echo "Building $image_name..."
  
  DOCKER_BUILDKIT=1 docker build -t "$image_name" -f "docker/$part.Dockerfile" --build-arg KL_VERSION="$tag" "$src_dir" \
    || { echo "\`docker build\` command failed, exiting! See log output above." >&2; exit 1; }
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