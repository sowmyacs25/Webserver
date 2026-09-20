#!/bin/bash
# ================================================================
# setup_ftp.sh — Configure ALL vulnerable services
# ================================================================
# WHAT THIS DOES:
#   1. Configures vsftpd to allow ANONYMOUS login + file upload
#   2. Configures ProFTPD with mod_copy (CVE-2015-3306)
#   3. Configures Apache + PHP (so mod_copy attack chain works)
#   4. Configures SSH with weak settings (root login allowed)
#
# WHY THESE ARE VULNERABILITIES:
#   - Anonymous FTP = anyone can download your files without a password
#   - mod_copy = attacker can copy files anywhere on the server
#     (e.g., copy a PHP hacking script into the website folder)
#   - Root SSH login = attackers can try to brute-force the root password
# ================================================================
set -e

# ──────────────────────────────────────────────────────────────────
# 1. VSFTPD — Anonymous FTP with Upload/Write (Intentional Vuln)
# ──────────────────────────────────────────────────────────────────
# WHAT: vsftpd is a popular FTP server. We're turning ON anonymous
#       access AND allowing anonymous users to UPLOAD files.
# WHY IT'S VULNERABLE: In a real company, anonymous upload means
#       anyone on the internet could dump malware on your server.
# ──────────────────────────────────────────────────────────────────
echo "[+] Configuring vsftpd (Anonymous Write)..."
cat > /etc/vsftpd.conf << 'EOF'
listen=YES
listen_ipv6=NO

# ─── THE VULNERABILITY: Anonymous users can read AND write ───
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
write_enable=YES

# Allow local users (ftpuser) to also log in via FTP
local_enable=YES
local_umask=022

# Where anonymous users land when they connect
anon_root=/var/ftp

# Logging
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES

# Banner — deliberately shows old version (tricks vulnerability scanners)
# Real version: 3.0.5, but banner says 2.3.4 (which had a famous backdoor)
ftpd_banner=VulnCorp FTP Server v2.3.4 — Internal Use Only

# No chroot = users can potentially browse outside their home directory
chroot_local_user=NO

# Passive mode ports (needed for data transfer in Docker)
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100

# Required for Docker — disables Linux seccomp sandboxing
seccomp_sandbox=NO
EOF

# ──────────────────────────────────────────────────────────────────
# 2. PROFTPD — mod_copy Vulnerability (CVE-2015-3306)
# ──────────────────────────────────────────────────────────────────
# WHAT: ProFTPD is another FTP server. mod_copy is a module that
#       lets you copy files on the server using SITE CPFR / SITE CPTO.
#
# THE BUG: mod_copy doesn't require authentication! So an attacker
#       can connect and copy ANY file to ANY location. The classic
#       attack is:
#         1. Upload a PHP hacking script via anonymous FTP
#         2. Use mod_copy to move it to /var/www/html/ (web folder)
#         3. Visit http://server/script.php in browser = FULL CONTROL
#
# CVE-2015-3306 affects ProFTPD versions before 1.3.5b
# ──────────────────────────────────────────────────────────────────
echo "[+] Configuring ProFTPD with mod_copy (CVE-2015-3306)..."
mkdir -p /etc/proftpd/conf.d
cat > /etc/proftpd/proftpd.conf << 'EOF'
ServerName "VulnCorp ProFTPD"
ServerType standalone
DefaultServer on
Port 2121

# RequireValidShell off = allows FTP login even if user's shell
# isn't in /etc/shells (makes anonymous access work in Docker)
RequireValidShell off

# ─── THE VULNERABILITY: mod_copy loaded without authentication ───
# This allows SITE CPFR (copy from) and SITE CPTO (copy to)
# commands WITHOUT logging in first!
LoadModule mod_copy.c

<Anonymous /var/ftp>
  User ftp
  Group nogroup
  RequireValidShell off
  UserAlias anonymous ftp
  <Limit WRITE>
    AllowAll
  </Limit>
</Anonymous>
EOF

# ──────────────────────────────────────────────────────────────────
# 3. APACHE + PHP — Web server (target for mod_copy attack)
# ──────────────────────────────────────────────────────────────────
# WHAT: Apache serves web pages. PHP lets it run scripts.
# WHY: The mod_copy attack chain needs Apache to EXECUTE the PHP
#       webshell that gets copied into /var/www/html/.
#       Without Apache+PHP, mod_copy can still move files around,
#       but the attacker can't get code execution through the browser.
# ──────────────────────────────────────────────────────────────────
echo "[+] Configuring Apache with PHP..."

# Enable PHP module in Apache
a2enmod php* 2>/dev/null || true

# Make the webroot writable by ProFTPD (so mod_copy can write there)
chmod 777 /var/www/html

# Create a simple landing page
cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>VulnCorp FTP Server — Internal Portal</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, sans-serif;
            background: #0a0e17;
            color: #c9d1d9;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
        }
        .container {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 12px;
            padding: 40px;
            max-width: 600px;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0,0,0,0.4);
        }
        h1 { color: #58a6ff; margin-bottom: 8px; }
        .subtitle { color: #8b949e; font-size: 14px; }
        .status { 
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 16px;
            margin-top: 24px;
            text-align: left;
            font-family: 'Courier New', monospace;
            font-size: 13px;
        }
        .status .ok { color: #3fb950; }
        .status .warn { color: #d29922; }
        .warning {
            margin-top: 24px;
            padding: 12px;
            background: #1c1208;
            border: 1px solid #d29922;
            border-radius: 6px;
            color: #d29922;
            font-size: 12px;
        }
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
            ⚠️ INTERNAL USE ONLY — Authorized VulnCorp personnel only.
            Contact IT helpdesk@vulncorp.local for access issues.
        </div>
    </div>
</body>
</html>
HTMLEOF

# ──────────────────────────────────────────────────────────────────
# 4. SSH — Weak configuration (Intentional)
# ──────────────────────────────────────────────────────────────────
# WHAT: SSH lets you log in remotely via command line.
# WHY VULNERABLE:
#   - Root login is allowed (attackers can try root passwords directly)
#   - MaxAuthTries 10 = lots of guesses before lockout
#   - Password auth = brute-force possible (vs key-only which is safer)
# ──────────────────────────────────────────────────────────────────
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
