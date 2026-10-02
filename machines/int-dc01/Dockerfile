FROM debian:bookworm-slim

LABEL maintainer="VulnCorp Lab"
LABEL description="int-dc01 — Active Directory Domain Controller (AS-REP, Kerberoast, DCSync, GPP, NTLM Relay)"
LABEL machine="7"

ENV DEBIAN_FRONTEND=noninteractive

# Install Samba 4 AD DC, Kerberos, LDAP, and utility packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        samba \
        samba-dsdb-modules \
        samba-vfs-modules \
        winbind \
        libpam-winbind \
        libnss-winbind \
        krb5-user \
        krb5-kdc \
        smbclient \
        ldap-utils \
        ldb-tools \
        openssh-server \
        python3 \
        procps \
        iproute2 \
        net-tools \
        curl \
        wget \
        vim \
        sudo \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration and setup scripts
COPY setup/ /opt/setup/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/setup/*.sh /entrypoint.sh

# Run AD DC provisioning and breadcrumbs setup
RUN /opt/setup/setup_dc.sh \
 && /opt/setup/setup_breadcrumbs.sh

# Generate SSH host keys
RUN mkdir -p /var/run/sshd && ssh-keygen -A

# Expose standard Active Directory Domain Controller ports
# 53: DNS | 88: Kerberos | 135: MSRPC | 139/445: SMB | 389/636: LDAP/S | 464: kpasswd | 3268: GC | 22: SSH
EXPOSE 22 53 88 135 139 389 445 464 636 3268 3269

ENTRYPOINT ["/entrypoint.sh"]
