FROM debian:bookworm-slim

LABEL org.opencontainers.image.description="Intentionally weak SSH target for local credential-attack practice. NOT for production use."

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# Intentionally weak credentials for lab practice only.
RUN useradd -m -s /bin/bash labuser \
    && echo 'labuser:password123' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
