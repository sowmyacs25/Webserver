FROM debian:bookworm-slim

LABEL maintainer="VulnCorp Lab"
LABEL description="dmz-ftp01 — Intentionally Vulnerable FTP Server (Anon Write, ProFTPD mod_copy)"
LABEL machine="3"

ENV DEBIAN_FRONTEND=noninteractive

# ================================================================
# WHAT THIS INSTALLS:
#   vsftpd       → FTP server with anonymous login enabled
#   proftpd      → Second FTP server with mod_copy bug (CVE-2015-3306)
#   apache2 + php → Web server so mod_copy attack can execute PHP scripts
#   openssh-server → SSH remote access
#   cron         → Task scheduler
#   gcc/make     → Development tools
# ================================================================
# 1. Install vsftpd, web services, SSH, and ProFTPD runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    vsftpd \
    apache2 \
    libapache2-mod-php \
    php \
    openssh-server \
    cron \
    python3 \
    gcc \
    make \
    curl wget net-tools vim sudo ftp telnet procps \
    libcap2 libssl3 libpam0g ucf \
    libhiredis0.14 libmemcached11 libmemcachedutil2 libncursesw6 libidn2-0 libacl1 netbase

# 2. Extract ProFTPD core binaries & modules without APT virtual package conflicts
RUN cd /tmp && \
    apt-get download proftpd-core && \
    dpkg-deb -x proftpd-core_*.deb / && \
    useradd -r -s /bin/false -d /run/proftpd proftpd 2>/dev/null || true && \
    mkdir -p /run/proftpd /var/run/proftpd && \
    rm -rf /tmp/proftpd* /var/lib/apt/lists/*

# ================================================================
# CREATE USERS — These are intentionally weak passwords (on purpose!)
#   root:toor         → Classic weak root password
#   ftpuser:ftp123    → FTP user with a guessable password
#   labadmin:labadmin123 → Lab admin account (matches Debian install)
# ================================================================
RUN echo "root:toor" | chpasswd
RUN useradd -m -s /bin/bash ftpuser && echo "ftpuser:ftp123" | chpasswd
RUN useradd -m -s /bin/bash labadmin && echo "labadmin:labadmin123" | chpasswd \
    && usermod -aG sudo labadmin

# Create FTP pub directory (world-writable so anyone can upload — that's the vuln!)
RUN mkdir -p /var/ftp/pub/keys && chmod -R 777 /var/ftp

# Create Apache webroot (this is where mod_copy will write files to)
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# Copy all setup scripts into the container
COPY setup/ /opt/setup/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /opt/setup/*.sh /entrypoint.sh

# Run setup scripts during build:
#   setup_ftp.sh        → Configures vsftpd, ProFTPD, Apache, SSH
#   setup_breadcrumbs.sh → Plants sensitive files, flags, and clues
RUN /opt/setup/setup_ftp.sh
RUN /opt/setup/setup_breadcrumbs.sh

# Generate SSH host keys
RUN mkdir -p /var/run/sshd && ssh-keygen -A

# ================================================================
# EXPOSED PORTS:
#   21         → vsftpd (anonymous FTP)
#   2121       → ProFTPD (mod_copy vulnerability)
#   22         → SSH
#   80         → Apache web server
#   40000-40100 → FTP passive data transfer ports
# ================================================================
EXPOSE 21 22 80 2121 40000-40100

ENTRYPOINT ["/entrypoint.sh"]
