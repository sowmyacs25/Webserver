FROM debian:bookworm-slim

LABEL maintainer="VulnCorp Lab"
LABEL description="dmz-ftp01 — Intentionally Vulnerable FTP Server (Anon Write, ProFTPD mod_copy)"
LABEL machine="3"

ENV DEBIAN_FRONTEND=noninteractive

# STEP 1: Base tooling + Apache/PHP + SSH + build deps
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
        iproute2 \
        libpcre2-posix3 \
        libpcre2-dev \
        libhiredis0.14 \
        libhiredis-dev \
        libmemcached11 \
        libmemcachedutil2 \
        libmemcached-dev \
        libncursesw6 \
        libncurses-dev \
        libidn2-0 \
        libidn2-dev \
        libacl1 \
        libacl1-dev \
        libcap2 \
        libcap-dev \
        libssl3 \
        libssl-dev \
        libpam0g \
        libpam0g-dev \
        netbase \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# STEP 2: vsftpd
RUN apt-get update && apt-get install -y --no-install-recommends vsftpd \
    && rm -rf /var/lib/apt/lists/*

# STEP 3: Build ProFTPD 1.3.5 from source (VULNERABLE to CVE-2015-3306)
RUN cd /tmp \
    && curl -fsSL https://gentoo.snt.utwente.nl/pub/software/proftpd/distrib/source/proftpd-1.3.5.tar.gz -o proftpd.tar.gz \
    && tar -xzf proftpd.tar.gz \
    && cd proftpd-1.3.5 \
    && ./configure --prefix=/usr \
                   --sysconfdir=/etc/proftpd \
                   --localstatedir=/var \
                   && make \
                   && make install \
                   && rm -rf /tmp/proftpd* \
                   && rm -rf /var/lib/apt/lists/*
# Users
RUN echo "root:toor" | chpasswd \
 && useradd -m -s /bin/bash ftpuser && echo "ftpuser:ftp123" | chpasswd \
 && useradd -m -s /bin/bash labadmin && echo "labadmin:labadmin123" | chpasswd \
 && usermod -aG sudo labadmin

# Runtime dirs
RUN mkdir -p /var/ftp/pub/keys \
             /var/www/html \
             /run/proftpd /var/run/proftpd \
             /var/run/vsftpd/empty \
             /var/run/sshd \
 && chmod -R 777 /var/ftp \
 && chmod 777 /var/www/html \
 && chown -R www-data:www-data /var/www/html

# Setup scripts
COPY setup/ /opt/setup/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/setup/*.sh /entrypoint.sh

RUN /opt/setup/setup_ftp.sh \
 && /opt/setup/setup_breadcrumbs.sh

RUN ssh-keygen -A

EXPOSE 21 22 80 2121 40000-40100

ENTRYPOINT ["/entrypoint.sh"]