FROM ubuntu:24.04

LABEL maintainer="VulnCorp Lab"
LABEL description="rz-vpn01 — VPN Admin Panel with Default Credentials + Path Traversal"
LABEL machine="5"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-flask \
    openssh-server \
    curl wget net-tools vim sudo \
    && pip3 install flask --break-system-packages \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vpnadmin && echo "vpnadmin:vpnadmin123" | chpasswd && \
    echo "vpnadmin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY setup/ /opt/setup/
COPY entrypoint.sh /entrypoint.sh

RUN mkdir -p /etc/openvpn/clients && chmod +x /opt/setup/*.sh /entrypoint.sh
RUN mkdir -p /var/run/sshd && ssh-keygen -A
RUN /opt/setup/setup_vpn.sh

EXPOSE 22 8443

ENTRYPOINT ["/entrypoint.sh"]
