FROM kalilinux/kali-rolling:latest

LABEL org.opencontainers.image.description="Kali Linux (XFCE + VNC) for personal use / CTF / learning only"

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        kali-linux-default \
        xfce4 \
        xfce4-terminal \
        dbus-x11 \
        tightvncserver \
        xfonts-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /root
EXPOSE 5901

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
