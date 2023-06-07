# syntax=docker/dockerfile:1.5.2

# registrar.Dockerfile
#
# Example usage:
#   DOCKER_BUILDKIT=1 docker build -f "docker/registrar.Dockerfile" -t "keylime_registrar:$KL_VERSION" \
#                                  --build-arg KL_VERSION "$KL_SRC_DIR"
#   docker network create keylime-net
#   docker run -itd --name keylime_registrar --net keylime-net \
#                   -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime \
#                   -v kl-vrt-src-vol:/usr/local/src/keylime \
#                   -p 8890:8890 -p 8891:8891 \
#                   --restart unless-stopped \
#                   "keylime_registrar:$KL_VERSION"
#
#   Note: Set KL_VERSION to the Keylime version you are using and KL_SRC_DIR to the path of the directory
#         containing the Keylime source code.

ARG KL_VERSION

FROM keylime_base:${KL_VERSION} AS keylime_registrar

LABEL version=${KL_VERSION}
LABEL description="Keylime Registrar"

EXPOSE 8890
EXPOSE 8891

ENTRYPOINT ["keylime_registrar"]