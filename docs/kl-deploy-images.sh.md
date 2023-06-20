# Container Image Builder (kl-deploy-images.sh)

Supports building Dockers images for the specified Keylime components using source code obtained from various locations. Running `kl-deploy-images.sh -h` gives a listing of options and usage examples:

```
Builds Keylime Docker images locally and optionally pushes them to GCR.

Usage: kl-deploy-images.sh <components> [opts...]

Options:
-r <repo>       : the URL to the remote Git repo containing the source
-b <branch>     : the name of the branch to check out (default: "master")
-d <dir>        : the path to the Keylime source directory (default: "./keylime")
-c <components> : a string indicating which Keylime components to build from the source directory; use "v" for the verifier, "r" for the registrar, "t" for the tenant, "a" for the agent, or combine these characters to build multiple components (default: "vrt").
-t <tag>        : a tag to apply to the built images (defaults to the current timestamp)
-p <registry>   : the Docker registry to push the images to
-h              : display help text

Examples:

kl-deploy-images.sh -r git@github.com:keylime/keylime.git -p gcr.io/project-keylime
  Retrieves Keylime source code, builds verifier, registrar and tenant images and pushes these to GCR.

kl-deploy-images.sh -r git@github.com:keylime/rust-keylime.git -d ./rust-keylime -c a -p gcr.io/project-keylime
  Retrieves source code for the Rust agent, builds a Docker image and pushes it to GCR.

kl-deploy-images.sh -r git@github.com:hse-aurora/keylime.git -b develop -c vt
  Retrieves the develop branch of the internal Keylime repo and only builds Docker images for the verifier and tenant.

kl-deploy-images.sh -d ~/keylime -c t -p gcr.io/project-keylime
  Builds an image for the tenant from a specific source directory and pushes it to GCR.
```