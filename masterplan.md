# 🏭 VulnCorp Enterprise Testbed — Master Plan
> **Classification:** INTERNAL — Educational / Lab Use Only  
> **Version:** 1.0  
> **Last Updated:** 2026-09-02  
> **Author:** VulnCorp Security Team  

---

## 🎯 Overview & Philosophy

This testbed simulates a **large-scale corporate IT environment** split into three security zones. It is designed as an industry-grade, multi-stage CTF where attackers start from the internet and must pivot zone by zone to reach the crown jewels deep in the internal network.

The lab covers the **entire kill chain**:

```
INTERNET → [DMZ] → [Restricted Zone] → [Internal Zone] → DOMAIN COMPROMISE
```

Each zone has dedicated machines with realistic services, misconfigurations, software vulnerabilities, and breadcrumbs that lead deeper into the network. Flags are embedded throughout the environment to track progress.

---

## 🗺️ Network Architecture

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                            INTERNET / ATTACKER                               ║
╚══════════════════════════════════════════╦═══════════════════════════════════╝
                                           │
                              ┌────────────▼────────────┐
                              │      EDGE FIREWALL       │
                              │  (fw-edge / 203.0.113.1) │
                              └────────────┬────────────┘
                                           │
          ┌────────────────────────────────▼──────────────────────────────────┐
          │                          DMZ ZONE                                  │
          │                     10.10.10.0/24                                  │
          │                                                                    │
          │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
          │  │ dmz-web01    │  │ dmz-mail01   │  │ dmz-ftp01    │            │
          │  │ 10.10.10.10  │  │ 10.10.10.20  │  │ 10.10.10.30  │            │
          │  │ Web/HTTP/SSH │  │ SMTP/IMAP    │  │ FTP/SFTP     │            │
          │  └──────────────┘  └──────────────┘  └──────────────┘            │
          └────────────────────────────┬──────────────────────────────────────┘
                                       │
                          ┌────────────▼────────────┐
                          │    INTERNAL FIREWALL     │
                          │     (fw-internal)        │
                          └────────────┬────────────┘
                                       │
          ┌────────────────────────────▼──────────────────────────────────────┐
          │                      RESTRICTED ZONE                               │
          │                      172.16.0.0/24                                 │
          │                                                                    │
          │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
          │  │ rz-db01      │  │ rz-vpn01     │  │ rz-monitor01 │            │
          │  │ 172.16.0.10  │  │ 172.16.0.20  │  │ 172.16.0.30  │            │
          │  │MySQL/Postgres │  │ OpenVPN/WG   │  │ Nagios/SNMP  │            │
          │  └──────────────┘  └──────────────┘  └──────────────┘            │
          └────────────────────────────┬──────────────────────────────────────┘
                                       │
                          ┌────────────▼────────────┐
                          │    CORE FIREWALL         │
                          │     (fw-core)            │
                          └────────────┬────────────┘
                                       │
          ┌────────────────────────────▼──────────────────────────────────────┐
          │                   INTERNAL APPLICATIONS ZONE                       │
          │                       192.168.1.0/24                               │
          │                                                                    │
          │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
          │  │ int-dc01     │  │ int-erp01    │  │ int-dev01    │            │
          │  │ 192.168.1.10 │  │ 192.168.1.20 │  │ 192.168.1.30 │            │
          │  │ AD/DNS/LDAP  │  │ ERP App/MSSQL│  │ GitLab/Jenkins│           │
          │  └──────────────┘  └──────────────┘  └──────────────┘            │
          │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
          │  │ int-files01  │  │ int-backup01 │  │ int-ws01     │            │
          │  │ 192.168.1.40 │  │ 192.168.1.50 │  │ 192.168.1.60 │            │
          │  │ Samba/NFS    │  │ Rsync/Bacula │  │ Win10/AD WS  │            │
          │  └──────────────┘  └──────────────┘  └──────────────┘            │
          └────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 ZONE 1 — DMZ (Demilitarized Zone) `10.10.10.0/24`

> **Purpose:** Internet-facing services. First point of contact for attackers.  
> **Firewall Policy:** Internet → DMZ (HTTP/HTTPS/SMTP/FTP only). DMZ → Internal (BLOCKED by default).

The DMZ is the attacker's entry point. Machines here must be compromised to gain footholds and harvest credentials/keys that allow pivoting inward.

---

### 🖥️ Machine 1: `dmz-web01` (10.10.10.10) — Corporate Web Portal

**OS:** Ubuntu 22.04 LTS  
**Hostname:** vulncorp-web01  
**Services:** Apache/Nginx (80/443), SSH (22), FTP (21)

> **Status:** ✅ ALREADY BUILT — `vulncorp-server` container in `docker-compose.yml`

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| W1 | SQL Injection (Login Bypass) | `/login` | CWE-89 | 🔴 CRITICAL | `VULN{sqli_byp4ss_g4t3w4y}` |
| W2 | OS Command Injection | `/nettools` | CWE-78 | 🔴 CRITICAL | — |
| W3 | Unrestricted File Upload (Webshell) | `/upload` | CWE-434 | 🔴 CRITICAL | — |
| W4 | Directory Traversal / LFI | `/viewer` | CWE-22 | 🟠 HIGH | `VULN{lfi_r34d_s3cr3ts}` |
| W5 | Stored XSS | `/notes` | CWE-79 | 🟠 HIGH | — |
| W6 | Information Disclosure | `/robots.txt`, `/server-status` | CWE-200 | 🟡 MEDIUM | — |
| W7 | Hardcoded Secret Key in Source | `app.py` | CWE-798 | 🟠 HIGH | — |
| W8 | SUID Binary → PATH Hijack (PrivEsc) | `/usr/local/bin/vuln-backup` | CWE-426 | 🔴 CRITICAL | `VULN{suid_p4th_h1j4ck}` |
| W9 | World-Writable Cron Job (PrivEsc) | `/opt/scripts/cleanup.sh` | CWE-732 | 🔴 CRITICAL | — |
| W10 | Sudo Misconfiguration (GTFOBins) | `find`, `vim` as root | CWE-269 | 🔴 CRITICAL | `VULN{pr1v3sc_r00t_pwn3d}` |
| W11 | World-readable `/etc/shadow` | File permissions | CWE-732 | 🔴 CRITICAL | — |
| W12 | Anonymous FTP with sensitive files | Port 21 | CWE-16 | 🟠 HIGH | `VULN{anon_ftp_l3ak}` |
| W13 | Plaintext credentials in SQLite DB | `/opt/vulncorp/db/` | CWE-312 | 🟠 HIGH | — |
| W14 | SSH Root Login Permitted | `/etc/ssh/sshd_config` | CWE-16 | 🟠 HIGH | — |

**Attack Path Summary:**
```
HTTP Enum → SQLi (bypass login) → Admin Panel (creds exposed)
         → Command Injection → Reverse Shell as webuser
         → PrivEsc (SUID / Cron / Sudo) → Root
         → Harvest SSH keys + DB creds → Pivot to rz-db01 (172.16.0.10)
```

**Root Flag:** `VULN{pr1v3sc_r00t_pwn3d_m4ch1n3_1}`

---

### 📧 Machine 2: `dmz-mail01` (10.10.10.20) — Corporate Mail Server

**OS:** Debian 11  
**Hostname:** vulncorp-mail01  
**Services:** Postfix SMTP (25, 587), Dovecot IMAP (143, 993), Roundcube Webmail (80), SSH (22)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| M1 | Roundcube Webmail RCE (CVE-2023-43770) | `/webmail` | CWE-20 | 🔴 CRITICAL | `VULN{m41l_rcm_rce_1n}` |
| M2 | SMTP Open Relay | Postfix config | CWE-16 | 🟠 HIGH | — |
| M3 | Email Header Injection | Contact form | CWE-93 | 🟡 MEDIUM | — |
| M4 | Dovecot Weak Credentials | IMAP brute-force | CWE-521 | 🟠 HIGH | — |
| M5 | Email Phishing Artifacts — internal creds in mailbox | Mailboxes | CWE-200 | 🟡 MEDIUM | `VULN{m41l_ph1sh_cr3ds}` |
| M6 | Local File Inclusion in Webmail Skin | Theme parameter | CWE-22 | 🟠 HIGH | — |
| M7 | Cleartext IMAP/SMTP (no TLS enforced) | Postfix/Dovecot config | CWE-319 | 🟡 MEDIUM | — |

**Credentials (to discover):**
- `admin@vulncorp.local` / `Admin@2024!`
- `sysadmin@vulncorp.local` / `Sysadmin#99` (found in email thread → VPN access)

**Attack Path Summary:**
```
SMTP Enum (VRFY/EXPN) → Brute-force IMAP → Read emails (find internal creds)
Roundcube Webmail → Exploit CVE-2023-43770 → RCE as www-data
→ PrivEsc via sudo postfix → Read mail queue (find VPN credentials)
→ Use VPN creds on rz-vpn01 (172.16.0.20)
```

**Root Flag:** `VULN{m41l_s3rv3r_0wn3d_m4ch1n3_2}`

---

### 📂 Machine 3: `dmz-ftp01` (10.10.10.30) — Public File Transfer Server

**OS:** CentOS 7  
**Hostname:** vulncorp-ftp01  
**Services:** vsftpd FTP (21), ProFTPD SFTP (22), HTTP (80, file listing)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| F1 | Anonymous FTP Write Access | vsftpd config | CWE-16 | 🟠 HIGH | `VULN{anon_ftp_wr1t3}` |
| F2 | ProFTPD mod_copy RCE (CVE-2015-3306) | `SITE CPFR / CPTO` commands | CWE-284 | 🔴 CRITICAL | `VULN{proftpd_rce_pwn3d}` |
| F3 | Sensitive Files in Public FTP Share | `/pub/` directory | CWE-200 | 🟡 MEDIUM | — |
| F4 | Weak FTP User Credentials | `ftpuser` / `ftp123` | CWE-521 | 🟠 HIGH | — |
| F5 | Directory Listing on HTTP | Apache `Options Indexes` | CWE-548 | 🟡 MEDIUM | — |
| F6 | SSH Private Key in FTP Share | `/pub/keys/backup_rsa` | CWE-312 | 🔴 CRITICAL | `VULN{ssh_k3y_l3ak3d}` |
| F7 | vsftpd 2.3.4 Backdoor (simulated) | vsftpd service | CWE-912 | 🔴 CRITICAL | — |

**Files exposed on FTP (breadcrumbs):**
- `network_map.txt` — full internal subnet map
- `backup_rsa` — SSH private key for `sysadmin` user
- `db_credentials.txt` — partially redacted database credentials
- `employee_list.csv` — usernames for password spraying

**Attack Path Summary:**
```
FTP Anon Login → Read sensitive files (network_map, backup_rsa)
ProFTPD mod_copy → Copy /etc/passwd to web root → LFI → RCE
→ PrivEsc via SUID find → Root
→ Use backup_rsa SSH key → Pivot to rz-db01 / rz-monitor01
```

**Root Flag:** `VULN{ftp_s3rv3r_r00t3d_m4ch1n3_3}`

---

## 🔒 ZONE 2 — Restricted Zone `172.16.0.0/24`

> **Purpose:** Backend services — databases, VPN concentrators, monitoring. Reachable only from DMZ or with VPN credentials.  
> **Firewall Policy:** DMZ → Restricted (specific ports only). Restricted → Internal (monitoring/admin traffic).

The Restricted Zone is the **middle layer** — more hardened than DMZ but riddled with misconfigured internal services, default credentials, and overprivileged service accounts.

---

### 🗄️ Machine 4: `rz-db01` (172.16.0.10) — Production Database Server

**OS:** Ubuntu 20.04 LTS  
**Hostname:** vulncorp-db01  
**Services:** MySQL 5.7 (3306), PostgreSQL 12 (5432), SSH (22), Redis (6379)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| D1 | MySQL Default root credentials (`root`/`toor`) | MySQL service | CWE-521 | 🔴 CRITICAL | `VULN{mysql_d3fault_cr3ds}` |
| D2 | MySQL `INTO OUTFILE` to write webshell | MySQL query | CWE-89 | 🔴 CRITICAL | — |
| D3 | PostgreSQL `COPY TO/FROM PROGRAM` RCE | PostgreSQL service | CWE-78 | 🔴 CRITICAL | `VULN{pg_rce_4_th3_w1n}` |
| D4 | Redis Unauthenticated Access (no bind, no auth) | Redis 6379 | CWE-306 | 🔴 CRITICAL | — |
| D5 | Redis `SLAVEOF` / `CONFIG SET dir` RCE | Redis service | CWE-284 | 🔴 CRITICAL | `VULN{r3d1s_rce_cron}` |
| D6 | Sensitive data stored in plaintext (PII dump) | MySQL `employees` DB | CWE-312 | 🟠 HIGH | `VULN{pii_d4t4_3xfil}` |
| D7 | MySQL UDF privilege escalation | `lib_mysqludf_sys` | CWE-269 | 🔴 CRITICAL | — |
| D8 | SSH user `dbadmin` with reused password | SSH service | CWE-521 | 🟠 HIGH | — |

**Databases of interest:**
- `vulncorp_prod` — employee PII, salary info, internal credentials table
- `vulncorp_hr` — HR records, leave data
- `vulncorp_auth` — hashed passwords (MD5, crackable with hashcat)

**Attack Path Summary:**
```
SSH with harvested creds (from dmz-web01 or dmz-ftp01)
→ MySQL root login → UDF privesc → OS Command Execution as root
Redis no-auth → CONFIG SET dir /var/spool/cron → Write cron → RCE
→ Root Shell → Dump all databases (find AD creds)
→ Find SSH config pointing to int-dc01 → Pivot to Internal Zone
```

**Root Flag:** `VULN{db_s3rv3r_r00t3d_m4ch1n3_4}`

---

### 🔐 Machine 5: `rz-vpn01` (172.16.0.20) — VPN Concentrator

**OS:** Ubuntu 20.04 LTS  
**Hostname:** vulncorp-vpn01  
**Services:** OpenVPN (1194/UDP), WireGuard (51820/UDP), SSH (22), Web Admin Panel (8443)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| V1 | OpenVPN Management Interface exposed (no auth) | Port 7505 (reachable via pivot) | CWE-306 | 🔴 CRITICAL | `VULN{vpn_mgmt_n0_4uth}` |
| V2 | Web Admin Panel Default Credentials (`admin`/`admin`) | :8443 web panel | CWE-521 | 🔴 CRITICAL | `VULN{vpn_w3b_d3f4ult}` |
| V3 | OpenVPN Config Injection via MITM | Lack of `tls-auth` | CWE-295 | 🟠 HIGH | — |
| V4 | SSH Key Reuse (same key as dmz-web01 root) | SSH authorized_keys | CWE-308 | 🟠 HIGH | — |
| V5 | Weak WireGuard Peer Pre-Shared Key | WireGuard config | CWE-521 | 🟡 MEDIUM | — |
| V6 | VPN Log File Contains Credentials | `/var/log/openvpn/openvpn.log` | CWE-532 | 🟠 HIGH | `VULN{vpn_l0g_cr3d_l34k}` |
| V7 | Sudo rule: `vpnadmin ALL=(ALL) NOPASSWD: /sbin/openvpn` | sudoers | CWE-269 | 🔴 CRITICAL | — |

**VPN Configs in /etc/openvpn/clients/ (breadcrumbs):**
- `it-admin.ovpn` — reveals internal network routing (`192.168.1.0/24`)
- `backup-agent.ovpn` — credentials for backup server account

**Attack Path Summary:**
```
Web Admin panel default creds → Download VPN client configs
→ Abuse OpenVPN management port (kill connections, inject routes)
→ SSH with reused key → PrivEsc via sudo openvpn → Root
→ VPN logs reveal AD admin credentials
→ Use those creds to access int-dc01 (192.168.1.10) via SMB/RDP
```

**Root Flag:** `VULN{vpn_s3rv3r_r00t3d_m4ch1n3_5}`

---

### 📊 Machine 6: `rz-monitor01` (172.16.0.30) — Monitoring & Alerting Server

**OS:** CentOS 8  
**Hostname:** vulncorp-monitor01  
**Services:** Nagios Core 4.4.6 (80), Zabbix Agent (10050), SSH (22), SNMP (161/UDP)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| MO1 | Nagios Core Authenticated RCE (CVE-2021-36383) | Nagios web panel | CWE-78 | 🔴 CRITICAL | `VULN{n4g10s_rce_m0n1t0r}` |
| MO2 | Nagios Default Credentials (`nagiosadmin`/`nagios`) | Web login | CWE-521 | 🔴 CRITICAL | `VULN{n4g10s_d3f4ult}` |
| MO3 | SNMP Community String `public` — full MIB walk | SNMP v1/v2c | CWE-16 | 🟠 HIGH | `VULN{snmp_c0mmun1ty_l34k}` |
| MO4 | Zabbix Agent Active Checks allow shell commands | Zabbix config | CWE-78 | 🔴 CRITICAL | — |
| MO5 | Nagios check scripts writable by nagios user | `/usr/local/nagios/libexec/` | CWE-732 | 🔴 CRITICAL | — |
| MO6 | SNMP v2c reveals full internal network topology | SNMP walk | CWE-200 | 🟠 HIGH | — |
| MO7 | SSH weak password for `monitor` user (`monitor123`) | SSH service | CWE-521 | 🟠 HIGH | — |
| MO8 | Nagios stores check results as world-readable | `/var/nagios/` | CWE-732 | 🟡 MEDIUM | — |

**SNMP Walk reveals (breadcrumbs):**
- Full ARP table (all internal IPs including 192.168.1.x)
- Network interface configurations
- Running process list (reveals internal application names)

**Attack Path Summary:**
```
SNMP walk → Enumerate full internal topology (reveal 192.168.1.0/24)
→ Nagios default creds → RCE via CVE-2021-36383 → Shell as nagios
→ Write malicious check plugin → PrivEsc via cron → Root
→ SSH keys in /var/nagios/ → Access int-erp01 (192.168.1.20)
```

**Root Flag:** `VULN{m0n1t0r_r00t3d_m4ch1n3_6}`

---

## 🏢 ZONE 3 — Internal Applications Zone `192.168.1.0/24`

> **Purpose:** Core business systems — Active Directory, ERP, DevOps, file shares, backup.  
> **Firewall Policy:** Heavily restricted ingress. Only internal traffic + VPN users permitted.  
> **This zone contains the crown jewels. Compromising `int-dc01` = full domain compromise = CTF WIN.**

The Internal Zone simulates a real corporate environment with layered defenses but realistic flaws — misconfigurations, insecure software, credential reuse, and shadow IT.

---

### 🏰 Machine 7: `int-dc01` (192.168.1.10) — Domain Controller

**OS:** Windows Server 2019  
**Hostname:** VULNCORP-DC01  
**Services:** Active Directory DS, DNS (53), LDAP (389/636), Kerberos (88), SMB (445), RDP (3389), WinRM (5985)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| DC1 | AS-REP Roasting — User has `DONT_REQ_PREAUTH` | AD user `svc_backup` | CWE-308 | 🔴 CRITICAL | `VULN{4sr3p_r04st_cr4ck3d}` |
| DC2 | Kerberoasting — Service account has SPN | AD users `svc_erp`, `svc_sql` | CWE-308 | 🔴 CRITICAL | `VULN{k3rb3r04st_svc_pwn3d}` |
| DC3 | PrintNightmare (CVE-2021-34527) | Windows Print Spooler | CWE-269 | 🔴 CRITICAL | `VULN{pr1ntn1ghtm4r3_dc}` |
| DC4 | NTLM Relay Attack (no SMB Signing) | SMB service | CWE-294 | 🔴 CRITICAL | — |
| DC5 | Password Spraying — Weak domain passwords | AD domain users | CWE-521 | 🟠 HIGH | `VULN{p4ssw0rd_spr4y_h1t}` |
| DC6 | DCSync Attack (svc_backup has Replicating Directory Changes) | AD privileges | CWE-269 | 🔴 CRITICAL | `VULN{dcs1nc_h4sh_dump3d}` |
| DC7 | BloodHound Path: svc_erp → GenericWrite → Domain Admins | AD ACL misconfiguration | CWE-732 | 🔴 CRITICAL | — |
| DC8 | RDP enabled with NLA disabled | RDP service | CWE-16 | 🟠 HIGH | — |
| DC9 | Local Administrator reused across machines | `Administrator` / `Corp@Admin2024` | CWE-521 | 🔴 CRITICAL | — |
| DC10 | SYSVOL GPP Password (cpassword) | Group Policy Preferences | CWE-312 | 🔴 CRITICAL | `VULN{gpp_p4ssw0rd_l34k}` |

**AD Users (to discover via LDAP/BloodHound):**

| Username | Description | Notable |
|----------|-------------|---------|
| `Administrator` | Domain Admin | Strong password but reused locally |
| `svc_backup` | Backup Service Account | AS-REP Roastable, DCSync rights |
| `svc_erp` | ERP Application Service | Kerberoastable, GenericWrite on DA group |
| `svc_sql` | SQL Service Account | Kerberoastable |
| `john.doe` | IT Admin | Member of Remote Desktop Users |
| `jane.smith` | Developer | Local admin on int-dev01 |
| `helpdesk` | Help Desk | Password: `Helpdesk@123` — spraying target |

**Attack Path Summary:**
```
LDAP anonymous bind → Enumerate users/groups
→ AS-REP Roast svc_backup → Crack hash offline (hashcat)
→ DCSync with svc_backup → Dump all NTLM hashes
→ Pass-the-Hash as Administrator → Full Domain Compromise
  OR
→ Kerberoast svc_erp → Crack ticket → GenericWrite abuse
→ Shadow Credentials / Resource-Based Constrained Delegation → Domain Admin
```

**Domain Flag (Ultimate CTF Win):** `VULN{d0m41n_4dm1n_3mp1r3_f3ll}`

---

### 💻 Machine 12: `int-ws01` (192.168.1.60) — Domain-Joined Windows 10 Workstation

**OS:** Windows 10 Enterprise  
**Hostname:** VULNCORP-WS01  
**Services:** SMB (445/139), RDP (3389), Print Spooler, WinRM  
**Domain:** `vulncorp.local` (joined to `int-dc01`)

> 📥 **Download:** https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| WS1 | EternalBlue (SMBv1 enabled) | SMB service (port 445) | CVE-2017-0144 | 🔴 CRITICAL | `VULN{3t3rn4l_blu3_w0rkst4t10n}` |
| WS2 | Stored plaintext credentials (Domain Admin) | `C:\Users\john.doe\Documents\` + SMB Public share | CWE-256 | 🟠 HIGH | `VULN{st0r3d_cr3ds_p1vot}` |
| WS3 | PrintNightmare (Print Spooler running) | Windows Spooler service | CVE-2021-34527 | 🔴 CRITICAL | `VULN{pr1ntn1ghtm4r3_dc}` |
| WS4 | Unquoted service path (VulnCorpMonitor) | `C:\Program Files\VulnCorp\Monitoring Agent\` | CWE-428 | 🟠 HIGH | — |
| WS5 | AlwaysInstallElevated (MSI privesc) | HKLM + HKCU registry | CWE-269 | 🟠 HIGH | — |
| WS6 | LLMNR / NetBIOS enabled (Responder vector) | Network stack | CWE-346 | 🟡 MEDIUM | — |
| WS7 | Weak local admin password | `ws_admin` / `Desktop@2024` | CWE-521 | 🟠 HIGH | `VULN{w0rkst4t10n_4dm1n_pwn3d}` |
| WS8 | RDP without NLA (port 3389) | Remote Desktop service | CWE-306 | 🟡 MEDIUM | — |

**Connection to int-dc01:** This machine is domain-joined to `int-dc01` (`192.168.1.10`). DNS, Kerberos (port 88), LDAP (port 389), and SMB all route through the DC. Domain Admin credentials (`john.doe` / `Corp@Admin2024`) are planted on this workstation, creating a direct pivot path from WS01 → DC01.

**Attack Path Summary:**
```
SMB guest access → \\192.168.1.60\Public\IT_Notes.txt → john.doe:Corp@Admin2024
  OR
EternalBlue (CVE-2017-0144) → SYSTEM on WS01 → Harvest stored credentials
  OR
LLMNR Poisoning (Responder) → NTLMv2 hash → Crack offline → Domain Admin
→ int-dc01 RDP/SMB → AS-REP Roast / DCSync → Full Domain Compromise
```

**Deploy:** `machines/int-ws01/deploy_ws.ps1` (run as Administrator on Windows 10)  
**Prerequisite:** `int-dc01` must be deployed and running first.

---

### 🏗️ Machine 8: `int-erp01` (192.168.1.20) — ERP / Business Application Server

**OS:** Windows Server 2016  
**Hostname:** VULNCORP-ERP01  
**Services:** IIS 10 (80/443), MS SQL Server 2017 (1433), WinRM (5985)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| E1 | MS SQL Server `sa` account enabled, weak password (`sa`/`sa`) | SQL Server | CWE-521 | 🔴 CRITICAL | `VULN{mssql_s4_pwn3d}` |
| E2 | MSSQL `xp_cmdshell` enabled | SQL Server config | CWE-78 | 🔴 CRITICAL | `VULN{xp_cmdsh3ll_rce}` |
| E3 | ERP Application IDOR — Access other users' records | `/erp/records?id=` | CWE-639 | 🟠 HIGH | `VULN{1d0r_3rp_r3c0rds}` |
| E4 | ERP App Business Logic Flaw — Negative invoice amounts | `/erp/invoice/create` | CWE-840 | 🟡 MEDIUM | — |
| E5 | SSRF in ERP document import feature | `/erp/import?url=` | CWE-918 | 🟠 HIGH | `VULN{ssrf_1nt3rn4l_s4n}` |
| E6 | IIS `web.config` exposed via path traversal | IIS misconfiguration | CWE-22 | 🔴 CRITICAL | — |
| E7 | .NET deserialization in ERP session cookie (ASP.NET ViewState) | ERP web app | CWE-502 | 🔴 CRITICAL | `VULN{d3s3r14l_v13wst4te}` |
| E8 | MSSQL linked server to int-dc01 (SQL → AD escalation) | SQL Server | CWE-269 | 🔴 CRITICAL | — |
| E9 | Outdated ERP version with known CVE (simulated RCE) | ERP software v2.1.0 | CWE-20 | 🔴 CRITICAL | — |
| E10 | Weak Windows local admin (`Administrator`/`Corp@Admin2024`) | Windows SAM | CWE-521 | 🔴 CRITICAL | — |

**Attack Path Summary:**
```
MSSQL sa login → Enable xp_cmdshell → RCE as MSSQL service account
→ MSSQL linked server → Pivot to DC01 SQL instance
→ PrivEsc via token impersonation (SeImpersonatePrivilege) → SYSTEM
→ Dump SAM/LSASS → Pass-the-Hash → Lateral movement to int-dc01
  OR
ERP Web SSRF → Scan internal network → Reach int-backup01 internal API
ERP .NET deserialization → SYSTEM shell directly
```

**SYSTEM Flag:** `VULN{erp_syst3m_pwn3d_m4ch1n3_8}`

---

### 💻 Machine 9: `int-dev01` (192.168.1.30) — Developer Workstation / CI-CD Server

**OS:** Ubuntu 22.04 LTS  
**Hostname:** vulncorp-dev01  
**Services:** GitLab CE (80/443), Jenkins (8080), SSH (22), Docker daemon exposed (2375)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| DEV1 | Docker daemon exposed without TLS on port 2375 | Docker API | CWE-306 | 🔴 CRITICAL | `VULN{d0ck3r_4p1_rce}` |
| DEV2 | GitLab CE SSRF → RCE (CVE-2021-22205) | GitLab web | CWE-918 | 🔴 CRITICAL | `VULN{g1tl4b_rce_ssrf}` |
| DEV3 | Secrets hardcoded in Git repo history | GitLab repo `vulncorp-infra` | CWE-798 | 🔴 CRITICAL | `VULN{g1t_h1st0ry_s3cr3ts}` |
| DEV4 | Jenkins Script Console enabled (no authentication) | Jenkins at :8080/script | CWE-306 | 🔴 CRITICAL | `VULN{j3nk1ns_scr1pt_rce}` |
| DEV5 | Jenkins build pipeline injects credentials as env vars | `Jenkinsfile` | CWE-214 | 🟠 HIGH | — |
| DEV6 | GitLab CI runner has sudo rights | `.gitlab-ci.yml` | CWE-269 | 🔴 CRITICAL | `VULN{g1tl4b_c1_sud0}` |
| DEV7 | `.env` file with AWS/cloud credentials committed to repo | Git repo | CWE-798 | 🔴 CRITICAL | `VULN{3nv_f1l3_cl0ud_k3ys}` |
| DEV8 | Docker container escape (privileged container running) | Docker | CWE-269 | 🔴 CRITICAL | `VULN{d0ck3r_3sc4p3_h0st}` |
| DEV9 | Insecure GitLab webhook → SSRF to internal metadata | GitLab webhooks | CWE-918 | 🟠 HIGH | — |
| DEV10 | SSH key of `jane.smith` (domain user) left on machine | `/home/jane.smith/.ssh/` | CWE-312 | 🟠 HIGH | — |

**Repos of interest (GitLab):**
- `vulncorp-infra` — Terraform/Ansible with hardcoded credentials
- `vulncorp-app` — Application source with raw SQL queries (no parameterization)
- `vulncorp-deploy` — Deployment scripts with AWS keys in commit history

**Attack Path Summary:**
```
Docker API (port 2375, no TLS) → docker run -v /:/host → Read host filesystem
→ Read /host/etc/shadow → Crack passwords
→ Docker privileged container escape → Root on host
  OR
GitLab CVE-2021-22205 → RCE → Git repo dump → Secrets extraction
Jenkins no-auth → Groovy script console → RCE as jenkins user
→ PrivEsc via sudo → Root → Find jane.smith SSH key
→ jane.smith is local admin on int-dc01 → Domain foothold
```

**Root Flag:** `VULN{d3v_s3rv3r_r00t3d_m4ch1n3_9}`

---

### 📁 Machine 10: `int-files01` (192.168.1.40) — File Server

**OS:** Windows Server 2016  
**Hostname:** VULNCORP-FILES01  
**Services:** SMB/CIFS (445), NFS (2049), FTP (21), RDP (3389)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| FS1 | EternalBlue (MS17-010) — unpatched SMB | SMB v1 enabled | CWE-119 | 🔴 CRITICAL | `VULN{3t3rn4lb1u3_pwn3d}` |
| FS2 | SMB Share with Everyone:Full Control | `\\FILES01\IT_Share` | CWE-732 | 🟠 HIGH | `VULN{smb_sh4r3_0p3n}` |
| FS3 | NFS Export with `no_root_squash` | `/exports/backup` | CWE-284 | 🔴 CRITICAL | `VULN{nfs_n0_r00t_squ4sh}` |
| FS4 | Password in Office document metadata | `IT_Procedures.docx` on share | CWE-312 | 🟠 HIGH | `VULN{d0cx_m3t4d4t4_l34k}` |
| FS5 | FTP anonymous upload to web-served directory | FTP + IIS | CWE-434 | 🔴 CRITICAL | — |
| FS6 | Sensitive PII files world-readable on NFS | `/exports/HR/` | CWE-732 | 🟠 HIGH | `VULN{nfs_pii_3xp0s3d}` |
| FS7 | Stale credential in Windows Credential Manager | `\\FILES01\Confidential` share | CWE-312 | 🔴 CRITICAL | — |

**Files of interest (on SMB/NFS shares):**
- `IT_Procedures.docx` — Document with embedded admin password hint
- `backup_scripts/` — Shell scripts containing database credentials
- `HR/salary_2024.xlsx` — PII data (flag embedded inside)
- `SSH_Keys/` — Private keys for various servers

**Attack Path Summary:**
```
EternalBlue → SYSTEM on FILES01 (direct, no patching)
  OR
SMB null session → Enumerate shares → Access IT_Share
→ Find backup scripts with DB creds
NFS no_root_squash → Mount export as local root → Add SSH key → RCE
→ Find credentials for Domain Admin in Credential Manager
→ PTH / RDP to int-dc01 → Domain compromise
```

**SYSTEM Flag:** `VULN{f1l3_s3rv3r_r00t3d_m4ch1n3_10}`

---

### 💾 Machine 11: `int-backup01` (192.168.1.50) — Backup Server

**OS:** Ubuntu 20.04 LTS  
**Hostname:** vulncorp-backup01  
**Services:** Bacula Director (9101), Bacula File Daemon (9102), Rsync (873), SSH (22)

#### Vulnerabilities

| # | Vulnerability | Location | CWE | Severity | Flag |
|---|--------------|----------|-----|----------|------|
| B1 | Rsync exposed with no authentication (`--no-auth`) | Port 873 | CWE-306 | 🔴 CRITICAL | `VULN{rsync_n04uth_dump}` |
| B2 | Bacula default passwords (`bacula`/`bacula`) | Bacula Director | CWE-521 | 🔴 CRITICAL | — |
| B3 | Full system backups accessible via rsync | `/backups/` module | CWE-284 | 🔴 CRITICAL | `VULN{rsync_full_b4ckup}` |
| B4 | Backup scripts run as root via cron, writable by backup user | `/opt/backup/run.sh` | CWE-732 | 🔴 CRITICAL | — |
| B5 | `/etc/rsyncd.conf` contains plaintext passwords for remote hosts | Rsync config | CWE-312 | 🟠 HIGH | `VULN{rsync_c0nf_cr3ds}` |
| B6 | Backup archives contain `/etc/shadow` of all servers | Backup files | CWE-312 | 🔴 CRITICAL | `VULN{b4ckup_sh4d0w_g0ld}` |
| B7 | SSH password reuse — `backupadmin` same password on all servers | SSH | CWE-521 | 🟠 HIGH | — |

**Backup modules (rsync exposed):**
- `full-backup/` — Contains full filesystem backups of int-dc01, int-erp01
- `db-backup/` — MySQL/MSSQL database dumps (plaintext)
- `config-backup/` — All server configuration files

**Attack Path Summary:**
```
Rsync no-auth → List modules → Download full-backup/
→ Extract /etc/shadow from backup → Crack offline (hashcat/john)
→ Find DC01's NTDS.dit backup → Extract AD hashes with secretsdump
→ Use any DA hash → Domain Admin → Full Compromise!
  OR
Backup cron writable → PrivEsc to root → SSH to all servers (password reuse)
```

**Root Flag:** `VULN{b4ckup_s3rv3r_r00t3d_m4ch1n3_11}`

---

## 🎯 Full Attack Chain — Storyline

```
[INTERNET]
     │
     ▼
[1] Scan dmz-web01 (10.10.10.10)
     └─ SQLi login bypass → Admin creds exposed
     └─ Command injection → Shell as webuser
     └─ PrivEsc (SUID / Cron / Sudo) → Root
     └─ Find DB creds + SSH keys embedded in database
     │
[2] Pivot to dmz-ftp01 (10.10.10.30)
     └─ Anonymous FTP → backup_rsa key + network_map
     └─ ProFTPD mod_copy → RCE → Root
     │
[3] Pivot to dmz-mail01 (10.10.10.20)
     └─ Brute IMAP → Read email (VPN credentials found inside)
     └─ Roundcube RCE → Root
     │
     ▼ [Now inside Restricted Zone via stolen creds / SSH pivoting]
     │
[4] Access rz-db01 (172.16.0.10)
     └─ MySQL default creds → UDF RCE → Root
     └─ Redis no-auth → Cron injection → Root
     └─ Dump all databases → Find AD service account hash
     │
[5] Access rz-monitor01 (172.16.0.30)
     └─ SNMP walk → Full internal network topology revealed
     └─ Nagios default creds → RCE → Root
     │
[6] Access rz-vpn01 (172.16.0.20)
     └─ Web admin default → Download VPN configs
     └─ VPN logs reveal AD admin password
     │
     ▼ [Now inside Internal Zone via VPN / SMB relay / SSH tunnels]
     │
[7] Access int-dev01 (192.168.1.30)
     └─ Docker API open → Container escape → Root
     └─ GitLab RCE → Harvest .env secrets + Git history creds
     └─ Jenkins no-auth → Groovy RCE → Root
     │
[8] Access int-backup01 (192.168.1.50)
     └─ Rsync no-auth → Download backups (includes DC shadow + NTDS)
     └─ Crack hashes offline → Domain Admin credentials obtained
     │
[9] Access int-files01 (192.168.1.40)
     └─ EternalBlue → SYSTEM directly (no patch required)
     └─ SMB shares → Find more domain credentials
     │
[10] Access int-erp01 (192.168.1.20)
     └─ MSSQL sa + xp_cmdshell → SYSTEM shell
     └─ Token impersonation (SeImpersonatePrivilege) → SYSTEM
     │
     ▼
[11] DOMAIN CONTROLLER — int-dc01 (192.168.1.10) ← CROWN JEWEL
     └─ AS-REP Roast svc_backup → Crack → DCSync
     └─ Pass-the-Hash / PTT (Silver/Golden Ticket)
     └─ Full AD Compromise → ALL flags collected
     └─ 🏆 VULN{d0m41n_4dm1n_3mp1r3_f3ll}
```

---

## 🏁 Flag Summary (Master List)

| # | Flag | Machine | Zone | Technique |
|---|------|---------|------|-----------|
| 1 | `VULN{sqli_byp4ss_g4t3w4y}` | dmz-web01 | DMZ | SQL Injection |
| 2 | `VULN{lfi_r34d_s3cr3ts}` | dmz-web01 | DMZ | Directory Traversal |
| 3 | `VULN{suid_p4th_h1j4ck}` | dmz-web01 | DMZ | SUID PrivEsc |
| 4 | `VULN{pr1v3sc_r00t_pwn3d}` | dmz-web01 | DMZ | Sudo GTFOBins |
| 5 | `VULN{anon_ftp_l3ak}` | dmz-web01 | DMZ | Anonymous FTP |
| 6 | `VULN{pr1v3sc_r00t_pwn3d_m4ch1n3_1}` | dmz-web01 | DMZ | Root Flag |
| 7 | `VULN{m41l_rcm_rce_1n}` | dmz-mail01 | DMZ | Roundcube RCE |
| 8 | `VULN{m41l_ph1sh_cr3ds}` | dmz-mail01 | DMZ | Email Phishing Artifacts |
| 9 | `VULN{m41l_s3rv3r_0wn3d_m4ch1n3_2}` | dmz-mail01 | DMZ | Root Flag |
| 10 | `VULN{anon_ftp_wr1t3}` | dmz-ftp01 | DMZ | Anonymous FTP Write |
| 11 | `VULN{proftpd_rce_pwn3d}` | dmz-ftp01 | DMZ | ProFTPD mod_copy RCE |
| 12 | `VULN{ssh_k3y_l3ak3d}` | dmz-ftp01 | DMZ | SSH Key in FTP Share |
| 13 | `VULN{ftp_s3rv3r_r00t3d_m4ch1n3_3}` | dmz-ftp01 | DMZ | Root Flag |
| 14 | `VULN{mysql_d3fault_cr3ds}` | rz-db01 | Restricted | MySQL Default Creds |
| 15 | `VULN{pg_rce_4_th3_w1n}` | rz-db01 | Restricted | PostgreSQL RCE |
| 16 | `VULN{r3d1s_rce_cron}` | rz-db01 | Restricted | Redis RCE via Cron |
| 17 | `VULN{pii_d4t4_3xfil}` | rz-db01 | Restricted | PII Data Exfiltration |
| 18 | `VULN{db_s3rv3r_r00t3d_m4ch1n3_4}` | rz-db01 | Restricted | Root Flag |
| 19 | `VULN{vpn_mgmt_n0_4uth}` | rz-vpn01 | Restricted | OpenVPN Mgmt No Auth |
| 20 | `VULN{vpn_w3b_d3f4ult}` | rz-vpn01 | Restricted | Default Credentials |
| 21 | `VULN{vpn_l0g_cr3d_l34k}` | rz-vpn01 | Restricted | Log Credential Leak |
| 22 | `VULN{vpn_s3rv3r_r00t3d_m4ch1n3_5}` | rz-vpn01 | Restricted | Root Flag |
| 23 | `VULN{n4g10s_rce_m0n1t0r}` | rz-monitor01 | Restricted | Nagios RCE |
| 24 | `VULN{n4g10s_d3f4ult}` | rz-monitor01 | Restricted | Default Credentials |
| 25 | `VULN{snmp_c0mmun1ty_l34k}` | rz-monitor01 | Restricted | SNMP Community String |
| 26 | `VULN{m0n1t0r_r00t3d_m4ch1n3_6}` | rz-monitor01 | Restricted | Root Flag |
| 27 | `VULN{4sr3p_r04st_cr4ck3d}` | int-dc01 | Internal | AS-REP Roasting |
| 28 | `VULN{k3rb3r04st_svc_pwn3d}` | int-dc01 | Internal | Kerberoasting |
| 29 | `VULN{pr1ntn1ghtm4r3_dc}` | int-dc01 | Internal | PrintNightmare |
| 30 | `VULN{p4ssw0rd_spr4y_h1t}` | int-dc01 | Internal | Password Spraying |
| 31 | `VULN{dcs1nc_h4sh_dump3d}` | int-dc01 | Internal | DCSync |
| 32 | `VULN{gpp_p4ssw0rd_l34k}` | int-dc01 | Internal | GPP cPassword |
| 33 | `VULN{d0m41n_4dm1n_3mp1r3_f3ll}` | int-dc01 | Internal | 🏆 ULTIMATE DOMAIN FLAG |
| 34 | `VULN{mssql_s4_pwn3d}` | int-erp01 | Internal | MSSQL Default Creds |
| 35 | `VULN{xp_cmdsh3ll_rce}` | int-erp01 | Internal | xp_cmdshell RCE |
| 36 | `VULN{1d0r_3rp_r3c0rds}` | int-erp01 | Internal | IDOR |
| 37 | `VULN{ssrf_1nt3rn4l_s4n}` | int-erp01 | Internal | SSRF |
| 38 | `VULN{d3s3r14l_v13wst4te}` | int-erp01 | Internal | .NET Deserialization |
| 39 | `VULN{erp_syst3m_pwn3d_m4ch1n3_8}` | int-erp01 | Internal | SYSTEM Flag |
| 40 | `VULN{d0ck3r_4p1_rce}` | int-dev01 | Internal | Docker API RCE |
| 41 | `VULN{g1tl4b_rce_ssrf}` | int-dev01 | Internal | GitLab CVE RCE |
| 42 | `VULN{g1t_h1st0ry_s3cr3ts}` | int-dev01 | Internal | Git History Secrets |
| 43 | `VULN{j3nk1ns_scr1pt_rce}` | int-dev01 | Internal | Jenkins Console RCE |
| 44 | `VULN{g1tl4b_c1_sud0}` | int-dev01 | Internal | GitLab CI Sudo PrivEsc |
| 45 | `VULN{3nv_f1l3_cl0ud_k3ys}` | int-dev01 | Internal | .env Cloud Keys |
| 46 | `VULN{d0ck3r_3sc4p3_h0st}` | int-dev01 | Internal | Docker Container Escape |
| 47 | `VULN{d3v_s3rv3r_r00t3d_m4ch1n3_9}` | int-dev01 | Internal | Root Flag |
| 48 | `VULN{3t3rn4lb1u3_pwn3d}` | int-files01 | Internal | EternalBlue |
| 49 | `VULN{smb_sh4r3_0p3n}` | int-files01 | Internal | Open SMB Share |
| 50 | `VULN{nfs_n0_r00t_squ4sh}` | int-files01 | Internal | NFS no_root_squash |
| 51 | `VULN{d0cx_m3t4d4t4_l34k}` | int-files01 | Internal | DOCX Metadata Leak |
| 52 | `VULN{nfs_pii_3xp0s3d}` | int-files01 | Internal | NFS PII Exposure |
| 53 | `VULN{f1l3_s3rv3r_r00t3d_m4ch1n3_10}` | int-files01 | Internal | SYSTEM Flag |
| 54 | `VULN{rsync_n04uth_dump}` | int-backup01 | Internal | Rsync No Auth |
| 55 | `VULN{rsync_full_b4ckup}` | int-backup01 | Internal | Rsync Full Backup |
| 56 | `VULN{rsync_c0nf_cr3ds}` | int-backup01 | Internal | Rsync Config Creds |
| 57 | `VULN{b4ckup_sh4d0w_g0ld}` | int-backup01 | Internal | Backup Shadow File |
| 58 | `VULN{b4ckup_s3rv3r_r00t3d_m4ch1n3_11}` | int-backup01 | Internal | Root Flag |

**Total Flags: 58**

---

## 🛠️ Implementation Roadmap

### Phase 0 — Already Built ✅
- [x] `dmz-web01` — VulnCorp Flask web server (Docker)
- [x] SQLi, Command Injection, File Upload, Directory Traversal, XSS
- [x] SUID, Writable Cron, Sudo GTFOBins PrivEsc
- [x] Anonymous FTP, SSH, breadcrumbs to Machine 2

### Phase 1 — DMZ Expansion
- [ ] `dmz-mail01` — Postfix + Dovecot + Roundcube (Docker)
- [ ] `dmz-ftp01` — vsftpd + ProFTPD with mod_copy backdoor (Docker)
- [ ] Edge Firewall container (iptables rules as code)

### Phase 2 — Restricted Zone
- [ ] `rz-db01` — MySQL 5.7 + PostgreSQL + Redis (Docker Compose)
- [ ] `rz-vpn01` — OpenVPN + Web Admin Panel (Docker)
- [ ] `rz-monitor01` — Nagios Core + SNMP agent (Docker)
- [ ] Internal Firewall (iptables rules)

### Phase 3 — Internal Zone
- [ ] `int-dev01` — GitLab CE + Jenkins + Docker-in-Docker (Docker)
- [ ] `int-backup01` — Rsync + Bacula (Docker / Linux VM)
- [ ] `int-files01` — Samba + NFS + SMBv1 (Docker / Linux VM)
- [ ] `int-erp01` — Custom Flask ERP + PostgreSQL (Docker)
- [ ] `int-dc01` — Active Directory (Windows Server 2019 VM — VirtualBox/VMware)
- [ ] `int-ws01` — Domain-joined Workstation (Windows 10 Enterprise VM — VirtualBox/VMware)

### Phase 4 — Orchestration & Polish
- [ ] Master `docker-compose.yml` with all Linux containers and custom networks
- [ ] Network segmentation: Docker networks (`dmz-net`, `restricted-net`, `internal-net`)
- [ ] CTFd scoreboard instance (Docker)
- [ ] Player documentation / challenge descriptions
- [ ] Automated full deployment script
- [ ] Writeup documents (red team perspective)

---

## 📦 Technology Stack

| Machine | Technology | Deployment |
|---------|-----------|------------|
| dmz-web01 | Python/Flask, Apache | Docker ✅ |
| dmz-mail01 | Postfix, Dovecot, Roundcube PHP | Docker |
| dmz-ftp01 | vsftpd, ProFTPD, Apache | Docker |
| rz-db01 | MySQL 5.7, PostgreSQL 12, Redis 6 | Docker |
| rz-vpn01 | OpenVPN, web admin panel | Docker |
| rz-monitor01 | Nagios Core 4, Net-SNMP | Docker |
| int-dev01 | GitLab CE, Jenkins, Docker-in-Docker | Docker |
| int-backup01 | Rsync, Bacula, OpenSSH | Docker |
| int-files01 | Samba 4 (SMBv1), NFS, vsftpd | Docker / Linux VM |
| int-erp01 | Flask ERP, PostgreSQL/MSSQL | Docker / Windows VM |
| int-dc01 | Windows Server 2019, Active Directory | **Windows Server VM** |
| int-ws01 | Windows 10 Enterprise, domain-joined | **Windows 10 VM** |
| CTFd | CTFd scoreboard | Docker |
| Firewalls | iptables routing containers | Docker |

---

## 📋 Vulnerability Coverage Matrix

| Category | DMZ | Restricted | Internal |
|----------|-----|-----------|---------|
| Injection (SQLi, CMDi) | ✅ | ✅ | ✅ |
| Broken Auth / Weak Passwords | ✅ | ✅ | ✅ |
| Sensitive Data Exposure | ✅ | ✅ | ✅ |
| SSRF | ❌ | ❌ | ✅ |
| Broken Access Control / IDOR | ❌ | ❌ | ✅ |
| Security Misconfigurations | ✅ | ✅ | ✅ |
| Outdated Software / Known CVEs | ✅ | ✅ | ✅ |
| Insecure Deserialization | ❌ | ❌ | ✅ |
| Linux Privilege Escalation | ✅ | ✅ | ✅ |
| Windows Privilege Escalation | ❌ | ❌ | ✅ |
| Active Directory Attacks | ❌ | ❌ | ✅ |
| Lateral Movement / Pivoting | ✅ | ✅ | ✅ |
| Container Security | ❌ | ❌ | ✅ |
| Cryptographic Failures | ✅ | ✅ | ✅ |
| CI/CD Pipeline Attacks | ❌ | ❌ | ✅ |

---

## ⚠️ Operational Security & Responsible Use

> **This testbed is designed strictly for educational and ethical security research purposes.**

1. **Isolated Network Only** — Deploy on an air-gapped or strictly controlled network. Never expose to the public internet.
2. **No Real PII** — All employee data, credentials, and documents are entirely fictional.
3. **Legal Compliance** — All participants must sign a rules-of-engagement document before accessing the lab.
4. **Monitoring** — Enable logging on all machines to detect out-of-scope attacks.
5. **Resets** — Implement daily snapshot resets to preserve lab integrity between sessions.
6. **Flagging** — All flags use the `VULN{...}` format. Submit via the CTFd scoreboard.

---

*End of Master Plan — VulnCorp Enterprise Testbed v1.0*
