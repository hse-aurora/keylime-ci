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

# Expose configuration, data and source directories as volumes
VOLUME /etc/keylime
VOLUME /var/lib/keylime
VOLUME /usr/local/src/keylime
