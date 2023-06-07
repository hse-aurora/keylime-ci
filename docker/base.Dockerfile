# syntax=docker/dockerfile:1.5.2

# base.Dockerfile
#
# This file creates an image which can be used as a base for the verifier, registrar
# and tenant and performs the necessary setup common to these three components.
#
# Example usage:
#   DOCKER_BUILDKIT=1 docker build -f "docker/base.Dockerfile" -t "keylime_base:$KL_VERSION" \
#                                  --build-arg KL_VERSION "$KL_SRC_DIR"
#
#   Note: Set KL_VERSION to the Keylime version you are using and KL_SRC_DIR to the path of the directory
#         containing the Keylime source code.
#   
#   After, build the other components using verifier.Dockerfile, registrar.Dockerfile and tenant.Dockerfile.

FROM fedora:37 AS keylime_base

ARG KL_VERSION

LABEL version=${KL_VERSION}
LABEL description="Keylime Base: Provides a common environment for the verifier, registrar and tenant"

# Install dependencies
RUN dnf -y install dnf-plugins-core git python3-PyMySQL && \
    dnf -y builddep tpm2-tools
RUN git clone -b 5.4 https://github.com/tpm2-software/tpm2-tools.git && \
    cd tpm2-tools && \
    ./bootstrap && \
    ./configure && \
    make && make install && \
    cd .. && rm -rf tpm2-tools

# Copy Keylime source to /usr/local/src to support containerised development and run installer
COPY --link . /usr/local/src/keylime
RUN cd /usr/local/src/keylime && \
    ./installer.sh -o

# Change PYTHONPATH to look in the new source directory instead of site-packages
ENV PYTHONPATH=/usr/local/src/keylime

# Create keylime user and add it to the tss group. Then, run the verifier to create
# the cv_ca directory containing certs before assigning the keylime user as the owner
# of the /var/lib/keylime/ directory and its children (including cv_ca)
RUN useradd keylime && \
    usermod -a -G tss keylime && \
    timeout --preserve-status 30s keylime_verifier && \
    chown -R keylime:tss /var/lib/keylime/

# Making edits to the config files here allows containers for the verifier, registrar and tenant to share the same
# config volume without one container's copy of the config files overriding the others...
# See https://docs.docker.com/storage/volumes/#populate-a-volume-using-a-container where this behaviour is documented

# Modify default verifier configuration to accept outside connections and communicate
# with the registrar using its Docker alias (requires a bridge network)
RUN sed -i "s/^ip = 127.0.0.1$/ip = 0.0.0.0/" /etc/keylime/verifier.conf && \
    sed -i "s/^registrar_ip = 127.0.0.1$/registrar_ip = keylime_registrar/" /etc/keylime/verifier.conf && \
    sed -i "s/^registrar_port = 8881$/registrar_port = 8891/" /etc/keylime/verifier.conf

# Modify default registrar configuration to accept outside connections
RUN sed -i "s/^ip = 127.0.0.1$/ip = 0.0.0.0/" /etc/keylime/registrar.conf

# Modify default tenant configuration to communicate with the verifier and registrar
# using their Docker aliases (requires a bridge network)
RUN sed -i "s/^verifier_ip = 127.0.0.1$/verifier_ip = keylime_verifier/" /etc/keylime/tenant.conf && \
    sed -i "s/^registrar_ip = 127.0.0.1$/registrar_ip = keylime_registrar/" /etc/keylime/tenant.conf

# Expose configuration, data and source directories as volumes
VOLUME /etc/keylime
VOLUME /var/lib/keylime
VOLUME /usr/local/src/keylime
