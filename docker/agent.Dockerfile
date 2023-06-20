# syntax=docker/dockerfile:1.5.2

# agent.Dockerfile
#
# Example usage (forward TPM on host):
#   DOCKER_BUILDKIT=1 docker build -f "docker/agent.Dockerfile" -t "keylime_agent:$KL_AGENT_VERSION" \
#                                  --build-arg KL_AGENT_VERSION "$KL_AGENT_SRC_DIR"
#   docker network create keylime-net
#   docker run -itd --name keylime_agent --net keylime-net -p 9002:9002 \
#                   -v kl-data-vol:/var/lib/keylime -v kl-a-config-vol:/etc/keylime \
#                   -v kl-a-src-vol:/usr/local/src/rust-keylime \
#                   --tmpfs /var/lib/keylime/secure:size=1024k,mode=0700 \
#                   --device /dev/tpm0:/dev/tpm0 --device /dev/tpmrm0:/dev/tpmrm0 \
#                   --restart unless-stopped \
#                   "keylime_agent:$KL_AGENT_VERSION"
#
# Example usage (use software TPM emulator):
#   (Build image and create network, same as above.)
#   docker run -itd --name keylime_agent --net keylime-net -p 9002:9002 \
#                   -v kl-data-vol:/var/lib/keylime -v kl-a-config-vol:/etc/keylime \
#                   -v kl-a-src-vol:/usr/local/src/rust-keylime \
#                   --tmpfs /var/lib/keylime/secure:size=1024k,mode=0700 \
#                   --env TCTI="swtpm:host=swtpm,port=2321" --restart unless-stopped \
#                   "keylime_agent:$KL_AGENT_VERSION"
#
#   Note: Set KL_AGENT_VERSION to the Rust agent version you are using and KL_AGENT_SRC_DIR to the path
#         of the directory containing the Rust agent source code.

FROM fedora:37 AS keylime_agent

ARG $KL_AGENT_VERSION

LABEL version=${KL_AGENT_VERSION}
LABEL description="Keylime Rust Agent"

# Install dependencies
RUN dnf -y install gcc clang openssl-devel tpm2-tss-devel libarchive-devel
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

ENV PATH="/root/.cargo/bin:$PATH"

# Compile and install the Rust agent
COPY --link . /usr/local/src/rust-keylime
RUN cd /usr/local/src/rust-keylime && \
    make && \
    make install || true

# Note: `make install` above tries to install a systemd service which fails in a Docker container due to
#       the lack of a systemd install. As such, a non-zero exit code is ignored with `... || true`.

# Create keylime user and add it to the tss group. Then, create the /var/lib/keylime directory and assign
# the new keylime user as its owner.
RUN useradd keylime && \
    usermod -a -G tss keylime && \
    mkdir /var/lib/keylime && \
    chown -R keylime:tss /var/lib/keylime/

# Configure the rust agent to accept outside connections and communicate with the registrar using its Docker alias
ENV KEYLIME_AGENT_IP="0.0.0.0"
ENV KEYLIME_AGENT_REGISTRAR_IP="keylime_registrar"

# Expose configuration, data and source directories as volumes
VOLUME /etc/keylime
VOLUME /var/lib/keylime
VOLUME /usr/local/src/rust-keylime

EXPOSE 9002

ENTRYPOINT ["keylime_agent"]