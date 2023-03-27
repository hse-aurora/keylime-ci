FROM fedora:37 AS keylime_base
LABEL version="_version_" description="Keylime Rust Agent"

# RUN dnf -y install gcc clang cmake openssl-devel tpm2-tss-devel libarchive-devel zeromq-devel
RUN dnf -y install gcc clang openssl-devel tpm2-tss-devel libarchive-devel
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

ENV PATH="/root/.cargo/bin:$PATH"

RUN --mount=type=bind,target=/rust-keylime,source=.,rw \
    cd /rust-keylime && \
    make && \
    make install || true

# Note: `make install` above tries to install a systemd service which fails in a Docker container due to the lack of a systemd install.
# As such, a non-zero exit code is ignored with `... || true`.

RUN useradd keylime && \
    usermod -a -G tss keylime && \
    mkdir /var/lib/keylime && \
    chown -R keylime:tss /var/lib/keylime/

ENV KEYLIME_AGENT_IP="0.0.0.0"
ENV KEYLIME_AGENT_REGISTRAR_IP="keylime_registrar"

VOLUME /etc/keylime
VOLUME /var/lib/keylime

EXPOSE 9002

ENTRYPOINT ["keylime_agent"]