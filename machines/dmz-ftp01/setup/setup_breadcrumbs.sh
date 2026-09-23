#!/bin/bash
# ================================================================
# setup_breadcrumbs.sh — Plant sensitive files, flags & clues
# ================================================================
# WHAT ARE BREADCRUMBS?
#   In cybersecurity labs, "breadcrumbs" are intentionally planted
#   clues that guide the attacker from one machine to the next.
#   In a real hack, attackers find these kinds of files accidentally
#   left behind by careless employees.
#
# WHAT THIS PLANTS:
#   - Network map (shows all internal server IPs)
#   - Database credentials (partial — hints at the DB server)
#   - Employee list (for password guessing attacks)
#   - SSH private key (for direct access to other servers)
#   - Hidden maintenance notes (with SSH passwords)
#   - 3 CTF flags (VULN{...} strings = proof you found the vuln)
# ================================================================
set -e
mkdir -p /var/ftp/pub/keys
echo "[+] Planting sensitive files in FTP pub..."

# ──────────────────────────────────────────────────────────────────
# 1. NETWORK MAP — Reveals the entire internal network
# ──────────────────────────────────────────────────────────────────
# WHY: In a real company, someone dumped the network diagram onto
#      the public FTP share. An attacker finding this now knows
#      every server IP and what services they run.
# ──────────────────────────────────────────────────────────────────
cat > /var/ftp/pub/network_map.txt << 'EOF'
VulnCorp Internal Network Map
==============================
CLASSIFIED — FOR IT DEPARTMENT USE ONLY

DMZ Zone:         10.10.10.0/24
  Web Server:     10.10.10.10   (HTTP 80, SSH 22, FTP 21)
  Mail Server:    10.10.10.20   (SMTP 25, IMAP 143, HTTP 80)
  FTP Server:     10.10.10.30   (FTP 21, ProFTPD 2121)

Restricted Zone:  172.16.0.0/24
  Database:       172.16.0.10   (MySQL 3306, PostgreSQL 5432, Redis 6379)
  VPN:            172.16.0.20   (OpenVPN 1194, Web Admin 8443)
  Monitoring:     172.16.0.30   (Nagios 80, SNMP 161)

Internal Zone:    192.168.1.0/24
  Domain Ctrl:    192.168.1.10  (AD, LDAP 389, Kerberos 88, RDP 3389)
  ERP Server:     192.168.1.20  (HTTP 80, PostgreSQL 5432)
  Dev Server:     192.168.1.30  (GitLab 80, Jenkins 8080, Docker 2375)
  File Server:    192.168.1.40  (SMB 445, NFS 2049)
  Backup Server:  192.168.1.50  (rsync 873)

Default Gateway:  10.10.10.1 (DMZ), 172.16.0.1 (RZ), 192.168.1.1 (INT)
DNS:              192.168.1.10 (Domain Controller)

Notes: 
  - VPN admin console at https://172.16.0.20:8443
  - Credentials stored on IT share at 192.168.1.40
  - Backup rsync runs nightly from 192.168.1.50
EOF

# ──────────────────────────────────────────────────────────────────
# 2. DATABASE CREDENTIALS — Partial but enough to be dangerous
# ──────────────────────────────────────────────────────────────────
# WHY: Someone left a partial creds file. The masked password "t**r"
#      is easily guessable as "toor" — classic weak DB password.
# ──────────────────────────────────────────────────────────────────
cat > /var/ftp/pub/db_credentials.txt << 'EOF'
[REDACTED — PARTIAL BACKUP]
VulnCorp Database Access Credentials
Last Updated: 2026-08-15

MySQL Production:
  Host: 172.16.0.10
  Port: 3306
  User: root
  Password: t**r   (see IT team for full credentials)
  Database: vulncorp_prod

PostgreSQL:
  Host: 172.16.0.10
  Port: 5432
  User: vulncorp_user
  Password: vuln@pg2024
  Database: vulncorp_prod

Redis:
  Host: 172.16.0.10
  Port: 6379
  Auth: (none configured — scheduled for Q4 fix)

IMPORTANT: Do NOT share these credentials outside IT department.
Contact: sysadmin@vulncorp.local
EOF

# ──────────────────────────────────────────────────────────────────
# 3. EMPLOYEE LIST — For password spraying / guessing attacks
# ──────────────────────────────────────────────────────────────────
# WHY: Attackers use employee usernames to try common passwords.
#      This is called "password spraying" — try one password against
#      many usernames to avoid lockout.
# ──────────────────────────────────────────────────────────────────
cat > /var/ftp/pub/employee_list.csv << 'EOF'
FirstName,LastName,Username,Email,Department,StartDate
John,Doe,john.doe,john.doe@vulncorp.local,IT,2020-01-15
Jane,Smith,jane.smith,jane.smith@vulncorp.local,Development,2021-03-22
Admin,User,admin,admin@vulncorp.local,IT,2019-06-01
Sys,Admin,sysadmin,sysadmin@vulncorp.local,IT,2019-06-01
Help,Desk,helpdesk,helpdesk@vulncorp.local,Support,2022-09-10
Backup,Agent,svc_backup,svc_backup@vulncorp.local,IT,2021-11-05
Dev,Ops,devops,devops@vulncorp.local,Development,2023-01-20
EOF

# ──────────────────────────────────────────────────────────────────
# 4. LEAKED SSH PRIVATE KEY — Direct access to other servers
# ──────────────────────────────────────────────────────────────────
# WHY: An SSH private key is like a master key. If an attacker finds
#      this, they can log into any server that trusts this key —
#      no password needed! This key belongs to "sysadmin".
# ──────────────────────────────────────────────────────────────────
ssh-keygen -t rsa -b 2048 -f /var/ftp/pub/keys/backup_rsa -N "" -C "sysadmin@vulncorp.local" -q

# ──────────────────────────────────────────────────────────────────
# 5. HIDDEN MAINTENANCE NOTES — More credentials (hidden file)
# ──────────────────────────────────────────────────────────────────
# WHY: Files starting with "." are hidden in Linux (ls won't show them,
#      but ls -la will). Attackers always check for hidden files.
# ──────────────────────────────────────────────────────────────────
cat > /var/ftp/pub/.maintenance_notes.txt << 'EOF'
=== FTP Server Maintenance Notes ===
Last maintenance: 2026-08-20

SSH Access to this server:
  User: ftpuser
  Pass: ftp123

Backup server access (for nightly sync):
  Host: 192.168.1.50
  rsync port: 873
  Module: vulncorp_backup (no auth required)

VPN admin portal:
  URL: http://172.16.0.20:8443
  User: admin
  Pass: admin

Mail server:
  Host: 10.10.10.20
  SMTP: port 25 (open relay — no auth needed)
  
TODO: Fix anonymous FTP write access (low priority)
TODO: Rotate SSH keys (overdue by 6 months)
EOF

# ──────────────────────────────────────────────────────────────────
# 6. FLAGS — Proof that you found the vulnerability
# ──────────────────────────────────────────────────────────────────
# WHAT: CTF (Capture The Flag) flags are special strings that prove
#       you successfully exploited a vulnerability. In competitions,
#       you submit these strings to earn points.
# ──────────────────────────────────────────────────────────────────

# Flag 1: Found via anonymous FTP access (in the pub folder)
echo "VULN{anon_ftp_wr1t3}" > /var/ftp/pub/flag1.txt

# Flag 2: Found in the leaked SSH keys directory
echo "VULN{ssh_k3y_l3ak3d}" > /var/ftp/pub/keys/flag.txt

# Flag 3: Root flag — only readable after getting root access
echo "VULN{ftp_s3rv3r_r00t3d_m4ch1n3_3}" > /root/root.txt
chmod 600 /root/root.txt  # Only root can read this

# Set ownership so FTP anonymous user can read the pub files
chown -R ftp:ftp /var/ftp 2>/dev/null || true

echo "[+] FTP breadcrumbs planted!"
