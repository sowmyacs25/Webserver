#!/bin/bash
# ================================================================
# VulnCorp Lab — dmz-ftp01 Entrypoint
# ================================================================
# WHAT IS THIS?
#   This script runs every time the container starts.
#   It starts all the vulnerable services one by one.
#   Think of it as the "power on" sequence for this fake server.
# ================================================================

echo "============================================="
echo "  VulnCorp FTP Server (dmz-ftp01)            "
echo "  Machine 3 | DMZ Zone | 10.10.10.30         "
echo "============================================="

# Clean up stale PID files from previous runs
# (Without this, services crash when you restart the container)
rm -f /var/run/vsftpd/vsftpd.pid \
      /var/run/proftpd.pid \
      /var/run/apache2/apache2.pid \
      /var/run/sshd.pid \
      /var/run/crond.pid 2>/dev/null || true

# --- Start SSH (remote login) ---
echo "[*] Starting SSH..."
service ssh start || /usr/sbin/sshd

# --- Start vsftpd (the FTP server with anonymous write) ---
echo "[*] Starting vsftpd (Anonymous Write enabled)..."
# vsftpd needs its run directory
mkdir -p /var/run/vsftpd/empty
service vsftpd start || /usr/sbin/vsftpd /etc/vsftpd.conf &

# --- Start ProFTPD (the FTP server with mod_copy bug) ---
echo "[*] Starting ProFTPD (mod_copy / CVE-2015-3306)..."
service proftpd start || /usr/sbin/proftpd

# --- Start Apache (web server — target for mod_copy file writes) ---
echo "[*] Starting Apache + PHP..."
service apache2 start || /usr/sbin/apachectl start

# --- Start Cron (task scheduler — used for privilege escalation) ---
echo "[*] Starting Cron daemon..."
service cron start || /usr/sbin/cron

echo ""
echo "============================================="
echo "  dmz-ftp01 — All Services Running!          "
echo "============================================="

# Quick checks to confirm services are actually listening
echo ""
if ss -tlpn 2>/dev/null | grep -q ':21 '; then
    echo "[+] vsftpd:   Port 21   — LISTENING (Anon FTP Write)"
else
    echo "[!] vsftpd:   Port 21   — WARNING: may not be running"
fi

if ss -tlpn 2>/dev/null | grep -q ':2121 '; then
    echo "[+] ProFTPD:  Port 2121 — LISTENING (mod_copy RCE)"
else
    echo "[!] ProFTPD:  Port 2121 — WARNING: may not be running"
fi

if ss -tlpn 2>/dev/null | grep -q ':80 '; then
    echo "[+] Apache:   Port 80   — LISTENING (PHP webshell target)"
else
    echo "[!] Apache:   Port 80   — WARNING: may not be running"
fi

if ss -tlpn 2>/dev/null | grep -q ':22 '; then
    echo "[+] SSH:      Port 22   — LISTENING (mapped to 2222 on host)"
else
    echo "[!] SSH:      Port 22   — WARNING: may not be running"
fi

echo ""
echo "  Quick Access:"
echo "    FTP:     ftp localhost 21     (user: anonymous)"
echo "    ProFTPD: telnet localhost 2121 (SITE CPFR/CPTO)"
echo "    Web:     http://localhost      (mod_copy target)"
echo "    SSH:     ssh ftpuser@localhost -p 2222  (pw: ftp123)"
echo ""
echo "  ⚠️  FOR EDUCATIONAL USE ONLY"
echo "============================================="

# Keep container running (without this, Docker would exit immediately)
tail -f /dev/null
