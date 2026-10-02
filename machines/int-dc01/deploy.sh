#!/bin/bash
# ================================================================
# VulnCorp — Machine 7: int-dc01 One-Command Deploy Script
# ================================================================
set -e
echo "============================================="
echo "  Deploying VulnCorp Domain Controller (DC01)"
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

echo "[*] Building and starting int-dc01 container..."
docker compose up -d --build

echo ""
echo "============================================="
echo "  int-dc01 DEPLOYED SUCCESSFULLY!            "
echo "============================================="
echo "  Domain:    vulncorp.local (VULNCORP)"
echo "  Kerberos:  Port 88 (AS-REP & Kerberoast)"
echo "  LDAP:      Port 389 / 636"
echo "  SMB:       Port 445 (SYSVOL GPP cPassword)"
echo "  DNS:       Port 53"
echo "  SSH:       Port 2222"
echo "============================================="
