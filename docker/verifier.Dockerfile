# syntax=docker/dockerfile:1.5.2

# verifier.Dockerfile
#
# Example usage:
#   DOCKER_BUILDKIT=1 docker build -f "docker/verifier.Dockerfile" -t "keylime_verifier:$KL_VERSION" \
#                                  --build-arg KL_VERSION "$KL_SRC_DIR"
#   docker network create keylime-net
#   docker run -itd --name keylime_verifier --net keylime-net \
#                   -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime \
#                   -v kl-vrt-src-vol:/usr/local/src/keylime \
#                   -p 8880:8880 -p 8881:8881 \
#                   --restart unless-stopped \
#                   "keylime_verifier:$KL_VERSION"
#
#   Note: Set KL_VERSION to the Keylime version you are using and KL_SRC_DIR to the path of the directory
#         containing the Keylime source code.

ARG KL_VERSION

FROM keylime_base:${KL_VERSION} AS keylime_verifier

LABEL version=${KL_VERSION}
LABEL description="Keylime Verifier"

EXPOSE 8880
EXPOSE 8881

ENTRYPOINT ["keylime_verifier"]