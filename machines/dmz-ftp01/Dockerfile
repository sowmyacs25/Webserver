FROM debian:bookworm-slim

LABEL maintainer="VulnCorp Lab"
LABEL description="dmz-ftp01 — Intentionally Vulnerable FTP Server (Anon Write, ProFTPD mod_copy)"
LABEL machine="3"

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------
# STEP 1: Base tooling + Apache/PHP + SSH + common libs
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
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
        libpcre2-posix3 \
        libhiredis0.14 \
        libmemcached11 \
        libmemcachedutil2 \
        libncursesw6 \
        libidn2-0 \
        libacl1 \
        libcap2 \
        libssl3 \
        libpam0g \
        netbase \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# STEP 2: vsftpd
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends vsftpd \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# STEP 3: proftpd-core — install .deb, then let apt fix any missing deps
# ------------------------------------------------------------------
RUN apt-get update \
    && apt-get download proftpd-core \
    && dpkg --force-conflicts --force-overwrite -i proftpd-core_*.deb \
    && apt-get install -y -f --no-install-recommends \
    && rm -f proftpd-core_*.deb \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# Create users
# ------------------------------------------------------------------
RUN echo "root:toor" | chpasswd \
 && useradd -m -s /bin/bash ftpuser && echo "ftpuser:ftp123" | chpasswd \
 && useradd -m -s /bin/bash labadmin && echo "labadmin:labadmin123" | chpasswd \
 && usermod -aG sudo labadmin

# ------------------------------------------------------------------
# Runtime directories
# ------------------------------------------------------------------
RUN mkdir -p /var/ftp/pub/keys \
             /var/www/html \
             /run/proftpd /var/run/proftpd \
             /var/run/vsftpd/empty \
             /var/run/sshd \
 && chmod -R 777 /var/ftp \
 && chown -R www-data:www-data /var/www/html

# ------------------------------------------------------------------
# Copy and run setup scripts
# ------------------------------------------------------------------
COPY setup/ /opt/setup/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/setup/*.sh /entrypoint.sh

RUN /opt/setup/setup_ftp.sh \
 && /opt/setup/setup_breadcrumbs.sh

# ------------------------------------------------------------------
# SSH host keys
# ------------------------------------------------------------------
RUN ssh-keygen -A

EXPOSE 21 22 80 2121 40000-40100

ENTRYPOINT ["/entrypoint.sh"]