# syntax=docker/dockerfile:1.5.2

# tenant.Dockerfile
#
# Example usage:
#   DOCKER_BUILDKIT=1 docker build -f "docker/tenant.Dockerfile" -t "keylime_tenant:$KL_VERSION" \
#                                  --build-arg KL_VERSION "$KL_SRC_DIR"
#   docker network create keylime-net
#   docker run -it --rm --name keylime_tenant --net keylime-net \
#                       -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime \
#                       -v kl-vrt-src-vol:/usr/local/src/keylime "keylime_tenant:$KL_VERSION" <args...>
#
#   Notes: Set KL_VERSION to the Keylime version you are using and KL_SRC_DIR to the path of the directory
#          containing the Keylime source code.
#
#          Replace <args...> with arguments to pass to the keylime_tenant command, e.g. `-c cvstatus` to
#          get the status of the verifier.

ARG KL_VERSION

FROM keylime_base:${KL_VERSION} AS keylime_tenant

LABEL version=${KL_VERSION}
LABEL description="Keylime Tenant"

ENTRYPOINT ["keylime_tenant"]