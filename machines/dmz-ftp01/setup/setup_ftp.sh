#!/bin/bash
# ================================================================
# setup_ftp.sh — Configure ALL vulnerable services
# ================================================================
set -e

# ------------------------------------------------------------------
# 1. VSFTPD — Anonymous FTP with Upload/Write (the main vuln)
# ------------------------------------------------------------------
echo "[+] Configuring vsftpd..."
cat > /etc/vsftpd.conf << 'EOF'
listen=YES
listen_ipv6=NO

anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
write_enable=YES

local_enable=YES
local_umask=022

anon_root=/var/ftp

dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES

ftpd_banner=VulnCorp FTP Server v2.3.4 — Internal Use Only

chroot_local_user=NO

# Passive mode (Docker-friendly)
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
pasv_address=127.0.0.1

# Required for anonymous access under modern PAM
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
seccomp_sandbox=NO
EOF

# ------------------------------------------------------------------
# 2. PROFTPD — mod_copy (CVE-2015-3306)
#    On Debian bookworm, mod_copy is compiled INTO the proftpd binary.
#    We just need to make sure the module is available and allowed.
# ------------------------------------------------------------------
echo "[+] Configuring ProFTPD (mod_copy)..."
mkdir -p /etc/proftpd/conf.d
cat > /etc/proftpd/proftpd.conf << 'EOF'
ServerName "VulnCorp ProFTPD"
ServerType standalone
DefaultServer on
Port 2121
UseIPv6 off

RequireValidShell off
UseFtpUsers off

# mod_copy: on Debian this is built-in. No LoadModule line needed.
# If the module file exists, loading it is harmless:
<IfModule mod_copy.c>
</IfModule>

<Anonymous /var/ftp>
  User ftp
  Group nogroup
  UserAlias anonymous ftp
  RequireValidShell off
  <Limit WRITE>
    AllowAll
  </Limit>
</Anonymous>
EOF

# ProFTPD needs an ftp user to exist for anonymous
id ftp >/dev/null 2>&1 || useradd -r -d /var/ftp -s /usr/sbin/nologin ftp

# ------------------------------------------------------------------
# 3. APACHE + PHP
# ------------------------------------------------------------------
echo "[+] Configuring Apache..."
a2enmod php* 2>/dev/null || true
chmod 777 /var/www/html

cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>VulnCorp FTP Server — Internal Portal</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #0a0e17;
               color: #c9d1d9; display: flex; justify-content: center;
               align-items: center; min-height: 100vh; margin: 0; }
        .container { background: #161b22; border: 1px solid #30363d;
                     border-radius: 12px; padding: 40px; max-width: 600px;
                     text-align: center; box-shadow: 0 8px 32px rgba(0,0,0,0.4); }
        h1 { color: #58a6ff; margin-bottom: 8px; }
        .subtitle { color: #8b949e; font-size: 14px; }
        .status { background: #0d1117; border: 1px solid #30363d;
                  border-radius: 8px; padding: 16px; margin-top: 24px;
                  text-align: left; font-family: 'Courier New', monospace; font-size: 13px; }
        .ok { color: #3fb950; } .warn { color: #d29922; }
        .warning { margin-top: 24px; padding: 12px; background: #1c1208;
                   border: 1px solid #d29922; border-radius: 6px;
                   color: #d29922; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>&#128193; VulnCorp FTP Server</h1>
        <p class="subtitle">dmz-ftp01 | 10.10.10.30 | DMZ Zone</p>
        <div class="status">
            <p><span class="ok">[ACTIVE]</span> vsftpd — Port 21 (Anonymous Access)</p>
            <p><span class="ok">[ACTIVE]</span> ProFTPD — Port 2121 (File Management)</p>
            <p><span class="ok">[ACTIVE]</span> Apache — Port 80 (This Page)</p>
            <p><span class="warn">[NOTE]</span> FTP anonymous upload: ENABLED</p>
        </div>
        <div class="warning">
            &#9888; INTERNAL USE ONLY — Authorized VulnCorp personnel only.
            Contact IT helpdesk@vulncorp.local for access issues.
        </div>
    </div>
</body>
</html>
HTMLEOF

# ------------------------------------------------------------------
# 4. SSH — weak config
# ------------------------------------------------------------------
echo "[+] Configuring weak SSH..."
mkdir -p /var/run/sshd
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 10
UsePAM yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

echo "[+] FTP service setup complete!"