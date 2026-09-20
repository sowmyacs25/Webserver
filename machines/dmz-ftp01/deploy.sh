#!/bin/bash
# ================================================================
# VulnCorp — Machine 3: dmz-ftp01 One-Command Deploy Script
# ================================================================
set -e
echo "============================================="
echo "  Deploying VulnCorp FTP Server (dmz-ftp01)  "
echo "============================================="

if ! command -v docker &> /dev/null; then
    echo "[*] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

if ! docker compose version &> /dev/null; then
    echo "[*] Installing Docker Compose plugin..."
    apt-get update && apt-get install -y docker-compose-v2
fi

echo "[*] Building and starting dmz-ftp01 container..."
docker compose up -d --build

echo ""
echo "============================================="
echo "  dmz-ftp01 DEPLOYED SUCCESSFULLY!           "
echo "============================================="
echo "  vsftpd (Anon Write): Port 21"
echo "  ProFTPD (mod_copy):  Port 2121"
echo "  SSH:                 Port 2222"
echo "============================================="
