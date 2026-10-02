#!/bin/bash
# ================================================================
# setup_breadcrumbs.sh — Sensitive artifacts and flags for int-dc01
# ================================================================
set -e

echo "[+] Planting flags and breadcrumbs for int-dc01..."

mkdir -p /flags /root /home/john.doe /home/svc_backup /var/spool/drivers/x64

# 1. CTF Flags (All 7 Flags from Masterplan)
echo "VULN{4sr3p_r04st_cr4ck3d}"         > /flags/asrep_flag.txt
echo "VULN{k3rb3r04st_svc_pwn3d}"        > /flags/kerberoast_flag.txt
echo "VULN{pr1ntn1ghtm4r3_dc}"           > /flags/printnightmare_flag.txt
echo "VULN{p4ssw0rd_spr4y_h1t}"          > /flags/password_spray_flag.txt
echo "VULN{dcs1nc_h4sh_dump3d}"          > /flags/dcsync_flag.txt
echo "VULN{gpp_p4ssw0rd_l34k}"           > /flags/gpp_flag.txt
echo "VULN{d0m41n_4dm1n_3mp1r3_f3ll}"    > /flags/domain_flag.txt

# Root / Desktop flag
echo "VULN{d0m41n_4dm1n_3mp1r3_f3ll}"    > /root/domain_flag.txt
echo "VULN{d0m41n_4dm1n_3mp1r3_f3ll}"    > /root/root.txt
chmod 600 /root/root.txt /root/domain_flag.txt

# Print Spooler flag (PrintNightmare)
echo "VULN{pr1ntn1ghtm4r3_dc}"           > /var/spool/drivers/x64/flag.txt

# 2. Administrator Domain Notes
cat > /home/john.doe/domain_notes.txt << 'EOF'
=== VulnCorp Active Directory Infrastructure Notes ===
Domain Controller: VULNCORP-DC01 (192.168.1.10)
Domain:            vulncorp.local
Forest Functional: Windows Server 2016+

Domain Administrators:
  - Administrator (Corp@Admin2024)
  - john.doe (Corp@Admin2024)

Service Accounts:
  - svc_backup: Automated backup synchronization agent (DCSync privileges)
  - svc_erp:    ERP backend authentication service (SPN: HTTP/erp.vulncorp.local)
  - svc_sql:    Production MSSQL database engine (SPN: MSSQLSvc/sql.vulncorp.local:1433)

Emergency Local Password:
  Stored in SYSVOL GPP under {D86A75A3-9F9C-4D2A-98C3-6056B481078D}
  User: backdoor

Connected Infrastructure:
  - int-erp01:    192.168.1.20 (ERP Portal & MSSQL)
  - int-dev01:    192.168.1.30 (GitLab & Jenkins)
  - int-files01:  192.168.1.40 (Corporate File Shares)
  - int-backup01: 192.168.1.50 (Nightly Rsync / Bacula)
  - int-ws01:     192.168.1.60 (Domain Workstation)
EOF

chown -R john.doe:john.doe /home/john.doe 2>/dev/null || true
chmod 644 /home/john.doe/domain_notes.txt

# 3. Backup Agent Notes
cat > /home/svc_backup/backup_instructions.txt << 'EOF'
=== Backup Service Account Operations ===
Account: VULNCORP\svc_backup
Role:    Domain Directory Replication & Nightly Snapshot Export
Target:  int-backup01 (192.168.1.50)

Note: Kerberos Pre-Authentication is disabled for legacy compatibility
with ancient batch replication tools. DO NOT RE-ENABLE PRE-AUTH.
EOF

chown -R svc_backup:svc_backup /home/svc_backup 2>/dev/null || true
chmod 644 /home/svc_backup/backup_instructions.txt

# Allow read on flag directory
chmod -R 644 /flags/*.txt
chmod 755 /flags

echo "[+] Breadcrumbs and flags planted successfully!"
