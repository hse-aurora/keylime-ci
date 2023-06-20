# syntax=docker/dockerfile:1.5.2

# swtpm.Dockerfile
#
# Makes available a containerised software TPM emulator for use by the Keylime agent
# in lieu of a physical TPM or vTPM on the Docker host.
#
# Example usage:
#   DOCKER_BUILDKIT=1 docker build -f "docker/swtpm.Dockerfile" -t "swtpm:latest"
#   docker network create keylime-net
#   docker run -itd --name swtpm --net keylime-net --restart unless-stopped "swtpm:latest"
#
#   Then: make sure the TCTI environment variable is set when you create the keylime agent container, e.g.:
#     docker run -itd --name keylime_agent --net keylime-net --env TCTI="swtpm:host=swtpm,port=2321" ...

FROM fedora:37 AS swtpm

LABEL description="SWTPM: Software TPM Emulator"

RUN dnf -y install swtpm tpm-tools
RUN mkdir /var/swtpm

ENV TPM2TOOLS_TCTI="swtpm:port=2321"

EXPOSE 2321
EXPOSE 2322

ENTRYPOINT ["swtpm", "socket", "--tpmstate", "dir=/var/swtpm", "--tpm2", "--server", "type=tcp,port=2321,bindaddr=0.0.0.0", "--ctrl", "type=tcp,port=2322,bindaddr=0.0.0.0", "--flags", "not-need-init,startup-clear"]