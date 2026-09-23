FROM debian:bookworm-slim

LABEL maintainer="VulnCorp Lab"
LABEL description="dmz-ftp01 — Intentionally Vulnerable FTP Server (Anon Write, ProFTPD mod_copy)"
LABEL machine="3"

ENV DEBIAN_FRONTEND=noninteractive

# ---- Install everything in ONE layer (faster, fewer failure points) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
        vsftpd \
        proftpd-core \
        proftpd-mod-crypto \
        apache2 \
        libapache2-mod-php \
        php \
        php-cli \
        openssh-server \
        cron \
        python3 \
        gcc \
        make \
        curl wget net-tools vim sudo ftp telnet procps \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---- Create users (intentionally weak passwords) ----
RUN echo "root:toor" | chpasswd \
 && useradd -m -s /bin/bash ftpuser && echo "ftpuser:ftp123" | chpasswd \
 && useradd -m -s /bin/bash labadmin && echo "labadmin:labadmin123" | chpasswd \
 && usermod -aG sudo labadmin

# ---- Prepare runtime dirs ----
RUN mkdir -p /var/ftp/pub/keys \
             /var/www/html \
             /run/proftpd /var/run/proftpd \
             /var/run/vsftpd/empty \
             /var/run/sshd \
 && chmod -R 777 /var/ftp \
 && chown -R www-data:www-data /var/www/html

# ---- Copy setup scripts ----
COPY setup/ /opt/setup/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/setup/*.sh /entrypoint.sh

# ---- Run setup scripts during build ----
RUN /opt/setup/setup_ftp.sh \
 && /opt/setup/setup_breadcrumbs.sh

# ---- Generate SSH host keys ----
RUN ssh-keygen -A

# ---- Expose ports ----
EXPOSE 21 22 80 2121 40000-40100

ENTRYPOINT ["/entrypoint.sh"]