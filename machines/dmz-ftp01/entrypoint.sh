#!/bin/bash
# ================================================================
# VulnCorp Lab — dmz-ftp01 Entrypoint
# ================================================================

echo "============================================="
echo "  VulnCorp FTP Server (dmz-ftp01)            "
echo "  Machine 3 | DMZ Zone | 10.10.10.30         "
echo "============================================="

# Clean stale PID files
rm -f /var/run/vsftpd/vsftpd.pid \
      /var/run/proftpd/proftpd.pid \
      /run/proftpd/proftpd.pid \
      /var/run/apache2/apache2.pid \
      /var/run/sshd.pid \
      /var/run/crond.pid 2>/dev/null || true

mkdir -p /var/run/vsftpd/empty /var/run/sshd /run/proftpd

# --- SSH ---
echo "[*] Starting SSH..."
/usr/sbin/sshd

# --- vsftpd ---
echo "[*] Starting vsftpd (Anonymous Write enabled)..."
/usr/sbin/vsftpd /etc/vsftpd.conf &

# --- ProFTPD ---
echo "[*] Starting ProFTPD (mod_copy / CVE-2015-3306)..."
/usr/sbin/proftpd -c /etc/proftpd/proftpd.conf

# --- Apache ---
echo "[*] Starting Apache + PHP..."
/usr/sbin/apachectl start

# --- Cron ---
echo "[*] Starting Cron..."
/usr/sbin/cron

sleep 1

echo ""
echo "============================================="
echo "  dmz-ftp01 — All Services Running!          "
echo "============================================="
echo ""

check_port() {
    local port=$1 name=$2
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "[+] $name: Port $port — LISTENING"
    else
        echo "[!] $name: Port $port — WARNING: may not be running"
    fi
}

check_port 21   "vsftpd  (Anon FTP Write)"
check_port 2121 "ProFTPD (mod_copy RCE) "
check_port 80   "Apache  (PHP webshell)"
check_port 22   "SSH                     "

echo ""
echo "  Quick Access:"
echo "    FTP:     ftp <VM_IP> 21         (user: anonymous)"
echo "    ProFTPD: telnet <VM_IP> 2121    (SITE CPFR/CPTO)"
echo "    Web:     http://<VM_IP>         (mod_copy target)"
echo "    SSH:     ssh ftpuser@<VM_IP> -p 2222  (pw: ftp123)"
echo ""
echo "  WARNING: FOR EDUCATIONAL USE ONLY"
echo "============================================="

tail -f /dev/null