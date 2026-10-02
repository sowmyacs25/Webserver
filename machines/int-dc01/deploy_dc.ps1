# ================================================================
# VulnCorp — Machine 7: int-dc01 (Domain Controller)
# Automated AD DS & Vulnerability Deployment Script
# Run this in PowerShell as Administrator on Windows Server 2019
# ================================================================
# ⚠️  FOR EDUCATIONAL / LAB USE ONLY — NEVER DEPLOY TO PRODUCTION
# ================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  VulnCorp DC Deployment (VULNCORP-DC01)    " -ForegroundColor Cyan
Write-Host "  Machine 7 | Internal Zone | 192.168.1.10   " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# ──────────────────────────────────────────────────────────────────
# STAGE 1: Check Domain Controller Role & Promote if Needed
# ──────────────────────────────────────────────────────────────────
$compSys = Get-CimInstance Win32_ComputerSystem
$isDC = $compSys.DomainRole -in 4, 5

if (-not $isDC) {
    Write-Host "[*] System is not currently a Domain Controller." -ForegroundColor Yellow
    
    # 1.1 Ensure static IP configuration on primary adapter
    Write-Host "[*] Verifying network adapter settings..." -ForegroundColor Yellow
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if ($adapter) {
        $ip = (Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        Write-Host "[+] Current IP on $($adapter.Name): $ip" -ForegroundColor Gray
    }

    # 1.2 Install AD DS Feature
    if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
        Write-Host "[*] Installing Active Directory Domain Services role..." -ForegroundColor Yellow
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue
    }

    # 1.3 Promote to Forest Root (vulncorp.local)
    Write-Host "[*] Promoting server to Domain Controller for 'vulncorp.local'..." -ForegroundColor Yellow
    Import-Module ADDSDeployment

    Install-ADDSForest `
      -DomainName "vulncorp.local" `
      -DomainNetbiosName "VULNCORP" `
      -ForestMode "WinThreshold" `
      -DomainMode "WinThreshold" `
      -InstallDns:$true `
      -Force:$true `
      -SafeModeAdministratorPassword (ConvertTo-SecureString "Corp@Admin2024" -AsPlainText -Force)

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host "  The server will now REBOOT to complete DC promotion.          " -ForegroundColor Green
    Write-Host "  After reboot, log in as VULNCORP\Administrator (Corp@Admin2024)" -ForegroundColor Yellow
    Write-Host "  and RE-RUN this script: .\deploy_dc.ps1                        " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Green
    Exit
}

Write-Host "[+] Confirmed: Server is a promoted Domain Controller for vulncorp.local" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────
# STAGE 2: Configure Active Directory Objects & Intentional Flaws
# ──────────────────────────────────────────────────────────────────
Import-Module ActiveDirectory

$domainDN = "DC=vulncorp,DC=local"

# 2.1 Create Organizational Units
Write-Host "[*] Creating Organizational Units..." -ForegroundColor Yellow
$ous = @("VulnCorp Users", "Service Accounts", "Workstations")
foreach ($ou in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
        Write-Host "[+] Created OU: $ou" -ForegroundColor Green
    }
}

# 2.2 Create Domain Users
Write-Host "[*] Creating domain accounts..." -ForegroundColor Yellow
$users = @(
  @{
    Name="John Doe";
    SAM="john.doe";
    Pass="Corp@Admin2024";
    Desc="IT Systems Administrator";
    OU="OU=VulnCorp Users,$domainDN";
    Groups=@("Domain Admins", "Remote Desktop Users")
  },
  @{
    Name="Jane Smith";
    SAM="jane.smith";
    Pass="Jane@Dev2024";
    Desc="Senior Software Developer";
    OU="OU=VulnCorp Users,$domainDN";
    Groups=@("Remote Desktop Users")
  },
  @{
    Name="Help Desk";
    SAM="helpdesk";
    Pass="Helpdesk@123";
    Desc="IT Help Desk Support - Flag: VULN{p4ssw0rd_spr4y_h1t}";
    OU="OU=VulnCorp Users,$domainDN";
    Groups=@()
  },
  @{
    Name="Backup Agent";
    SAM="svc_backup";
    Pass="Backup@Svc2024";
    Desc="Automated Backup Service Account - Flag: VULN{4sr3p_r04st_cr4ck3d}";
    OU="OU=Service Accounts,$domainDN";
    Groups=@()
  },
  @{
    Name="ERP Service";
    SAM="svc_erp";
    Pass="Erp@Service99!";
    Desc="Enterprise Resource Planning Service - Flag: VULN{k3rb3r04st_svc_pwn3d}";
    OU="OU=Service Accounts,$domainDN";
    Groups=@()
  },
  @{
    Name="SQL Service";
    SAM="svc_sql";
    Pass="Sql@Service77!";
    Desc="Production Database SQL Service";
    OU="OU=Service Accounts,$domainDN";
    Groups=@()
  }
)

foreach ($u in $users) {
    $existing = Get-ADUser -Filter "SamAccountName -eq '$($u.SAM)'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADUser `
          -Name $u.Name `
          -SamAccountName $u.SAM `
          -UserPrincipalName "$($u.SAM)@vulncorp.local" `
          -AccountPassword (ConvertTo-SecureString $u.Pass -AsPlainText -Force) `
          -Enabled $true `
          -PasswordNeverExpires $true `
          -Description $u.Desc `
          -Path $u.OU
        Write-Host "[+] Created user: $($u.SAM)" -ForegroundColor Green
    } else {
        Set-ADUser -Identity $u.SAM -Description $u.Desc
        Write-Host "[*] User $($u.SAM) exists, updated description" -ForegroundColor Gray
    }

    # Add to groups
    foreach ($grp in $u.Groups) {
        try {
            Add-ADGroupMember -Identity $grp -Members $u.SAM -ErrorAction SilentlyContinue
            Write-Host "[+] Added $($u.SAM) to $grp" -ForegroundColor Green
        } catch {
            Write-Host "[-] Note: Could not add $($u.SAM) to $grp" -ForegroundColor Gray
        }
    }
}

# Update krbtgt description with DCSync Flag
try {
    Set-ADUser -Identity "krbtgt" -Description "KDC Master Kerberos Key Account - Flag: VULN{dcs1nc_h4sh_dump3d}" -ErrorAction SilentlyContinue
    Write-Host "[+] Updated krbtgt description with DCSync flag" -ForegroundColor Green
} catch {}

# ──────────────────────────────────────────────────────────────────
# 2.3 Vulnerability 1: AS-REP Roasting (CWE-308)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Configuring AS-REP Roasting on svc_backup..." -ForegroundColor Yellow
Set-ADAccountControl -Identity "svc_backup" -DoesNotRequirePreAuth $true
Write-Host "[+] VULN 1: svc_backup Kerberos Pre-Authentication DISABLED (AS-REP Roastable)" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────
# 2.4 Vulnerability 2: Kerberoasting (CWE-308)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Registering SPNs for Kerberoasting..." -ForegroundColor Yellow
Set-ADUser "svc_erp" -ServicePrincipalNames @{
    Add=@("HTTP/erp.vulncorp.local:80", "HTTP/erp.vulncorp.local", "HTTP/VULNCORP-ERP01")
} -ErrorAction SilentlyContinue

Set-ADUser "svc_sql" -ServicePrincipalNames @{
    Add=@("MSSQLSvc/sql.vulncorp.local:1433", "MSSQLSvc/sql.vulncorp.local", "MSSQLSvc/VULNCORP-DB01")
} -ErrorAction SilentlyContinue
Write-Host "[+] VULN 2: Registered SPNs on svc_erp & svc_sql (Kerberoastable)" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────
# 2.5 Vulnerability 3: DCSync Rights for svc_backup (CWE-269)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Granting DCSync replication rights to svc_backup..." -ForegroundColor Yellow
try {
    # Using dsacls (most reliable method in Active Directory)
    & dsacls "$domainDN" /G "VULNCORP\svc_backup:CA;Replicating Directory Changes" | Out-Null
    & dsacls "$domainDN" /G "VULNCORP\svc_backup:CA;Replicating Directory Changes All" | Out-Null
    & dsacls "$domainDN" /G "VULNCORP\svc_backup:CA;Replicating Directory Changes In Filtered Set" | Out-Null
    
    # Also apply GenericAll via PowerShell ACL
    $acl = Get-Acl "AD:\$domainDN"
    $sid = (Get-ADUser "svc_backup").SID
    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid, [System.DirectoryServices.ActiveDirectoryRights]"GenericAll", [System.Security.AccessControl.AccessControlType]"Allow")
    $acl.AddAccessRule($rule)
    Set-Acl -Path "AD:\$domainDN" -AclObject $acl
    Write-Host "[+] VULN 3: Granted Replicating Directory Changes & GenericAll to svc_backup" -ForegroundColor Green
} catch {
    Write-Host "[-] Note on DCSync ACL: $_" -ForegroundColor Yellow
}

# ──────────────────────────────────────────────────────────────────
# 2.6 Vulnerability 4: BloodHound Path — svc_erp GenericWrite on DA
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Granting GenericWrite / WriteProperty on Domain Admins to svc_erp..." -ForegroundColor Yellow
try {
    $daDN = "CN=Domain Admins,CN=Users,$domainDN"
    & dsacls "$daDN" /G "VULNCORP\svc_erp:WP" | Out-Null
    & dsacls "$daDN" /G "VULNCORP\svc_erp:GA" | Out-Null
    
    $daAcl = Get-Acl "AD:\$daDN"
    $erpSid = (Get-ADUser "svc_erp").SID
    $daRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($erpSid, [System.DirectoryServices.ActiveDirectoryRights]"WriteProperty", [System.Security.AccessControl.AccessControlType]"Allow")
    $daAcl.AddAccessRule($daRule)
    Set-Acl -Path "AD:\$daDN" -AclObject $daAcl
    Write-Host "[+] VULN 4: svc_erp has GenericWrite on Domain Admins (BloodHound Path)" -ForegroundColor Green
} catch {
    Write-Host "[-] Note on Domain Admins ACL: $_" -ForegroundColor Yellow
}

# ──────────────────────────────────────────────────────────────────
# 2.7 Vulnerability 5: SYSVOL GPP cPassword (CVE-2014-1812)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Planting Group Policy Preferences cPassword in SYSVOL..." -ForegroundColor Yellow
$sysvolLocal = "C:\Windows\SYSVOL\sysvol\vulncorp.local\Policies\{D86A75A3-9F9C-4D2A-98C3-6056B481078D}\Machine\Preferences\Groups"
New-Item -ItemType Directory -Force -Path $sysvolLocal | Out-Null

$gppXml = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- VulnCorp Legacy Group Policy Preference Deployment -->
<!-- FLAG: VULN{gpp_p4ssw0rd_l34k} -->
<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}">
  <Group clsid="{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}" name="Local Admins Policy" image="2" changed="2026-08-10 14:22:00" uid="{A37E3166-70DE-4E10-9E11-37E740924976}">
    <Properties action="U" newName="" groupName="Administrators" description="Emergency Domain Recovery Account">
      <Members>
        <Member name="backdoor" action="ADD">
          <!-- Password decrypts to: backdoor (AES-256 with MS published key) -->
          <Properties cpassword="VZBQoGpDMEUESqPnEFTqMg==" userName="backdoor" fullName="Emergency Recovery" description="Flag: VULN{gpp_p4ssw0rd_l34k}"/>
        </Member>
      </Members>
    </Properties>
  </Group>
</Groups>
'@

Set-Content -Path "$sysvolLocal\Groups.xml" -Value $gppXml -Encoding UTF8
Write-Host "[+] VULN 5: Planted GPP Groups.xml with cpassword in SYSVOL" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────
# 2.8 Vulnerability 6: SMB Signing Disabled (CVE-2008-4037)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Disabling SMB signing (NTLM Relay vector)..." -ForegroundColor Yellow
Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $false -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $false -Force
Write-Host "[+] VULN 6: SMB Signing DISABLED on Server and Client" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────
# 2.9 Vulnerability 7: PrintNightmare (CVE-2021-34527)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Configuring Print Spooler for PrintNightmare..." -ForegroundColor Yellow
try {
    Set-Service -Name Spooler -StartupType Automatic
    Start-Service -Name Spooler -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print" -Name "RpcAuthnLevelPrivacyEnabled" -Value 0 -Type DWord -Force
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -Name "NoWarningNoElevationOnInstall" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -Name "UpdatePromptSettings" -Value 2 -Type DWord -Force
    
    New-Item -Path "C:\Windows\System32\spool\drivers\x64" -ItemType Directory -Force | Out-Null
    "VULN{pr1ntn1ghtm4r3_dc}" | Set-Content "C:\Windows\System32\spool\drivers\x64\flag.txt" -Force
    Write-Host "[+] VULN 7: PrintNightmare PointAndPrint registry enabled & Spooler active" -ForegroundColor Green
} catch {
    Write-Host "[-] Note on PrintNightmare config: $_" -ForegroundColor Yellow
}

# ──────────────────────────────────────────────────────────────────
# 2.10 Vulnerability 8: RDP Without NLA (CWE-306)
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Enabling Remote Desktop without NLA..." -ForegroundColor Yellow
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
Write-Host "[+] VULN 8: RDP enabled on port 3389 without Network Level Authentication (NLA)" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────
# 2.11 Plant All 7 CTF Flags
# ──────────────────────────────────────────────────────────────────
Write-Host "[*] Planting all 7 CTF flags..." -ForegroundColor Yellow
$flagsDir = "C:\flags"
New-Item $flagsDir -ItemType Directory -Force | Out-Null

"VULN{4sr3p_r04st_cr4ck3d}"         | Set-Content "$flagsDir\asrep_flag.txt"
"VULN{k3rb3r04st_svc_pwn3d}"        | Set-Content "$flagsDir\kerberoast_flag.txt"
"VULN{pr1ntn1ghtm4r3_dc}"           | Set-Content "$flagsDir\printnightmare_flag.txt"
"VULN{p4ssw0rd_spr4y_h1t}"          | Set-Content "$flagsDir\password_spray_flag.txt"
"VULN{dcs1nc_h4sh_dump3d}"          | Set-Content "$flagsDir\dcsync_flag.txt"
"VULN{gpp_p4ssw0rd_l34k}"           | Set-Content "$flagsDir\gpp_flag.txt"
"VULN{d0m41n_4dm1n_3mp1r3_f3ll}"    | Set-Content "$flagsDir\domain_flag.txt"

# Administrator Desktop flag
$adminDesktop = "C:\Users\Administrator\Desktop"
if (Test-Path $adminDesktop) {
    "VULN{d0m41n_4dm1n_3mp1r3_f3ll}" | Set-Content "$adminDesktop\flag.txt" -Force
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VulnCorp DC Deployment COMPLETE!                              " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Machine:      int-dc01 (VULNCORP-DC01)                         " -ForegroundColor White
Write-Host "  Domain:       vulncorp.local (NetBIOS: VULNCORP)               " -ForegroundColor White
Write-Host "  IP:           192.168.1.10                                     " -ForegroundColor White
Write-Host ""
Write-Host "  Configured Vulnerabilities:                                    " -ForegroundColor Yellow
Write-Host "    [1] AS-REP Roasting:        svc_backup (preauth disabled)    " -ForegroundColor Gray
Write-Host "    [2] Kerberoasting:          svc_erp & svc_sql (SPNs active)  " -ForegroundColor Gray
Write-Host "    [3] DCSync Rights:          svc_backup (GenericAll on root)  " -ForegroundColor Gray
Write-Host "    [4] BloodHound Path:        svc_erp -> GenericWrite on DA    " -ForegroundColor Gray
Write-Host "    [5] GPP cPassword:          SYSVOL Groups.xml (backdoor)     " -ForegroundColor Gray
Write-Host "    [6] SMB Signing:            Disabled on Server and Client    " -ForegroundColor Gray
Write-Host "    [7] PrintNightmare:         Spooler active & PointAndPrint   " -ForegroundColor Gray
Write-Host "    [8] RDP without NLA:        Port 3389 open                   " -ForegroundColor Gray
Write-Host "    [9] Password Spraying:      helpdesk:Helpdesk@123            " -ForegroundColor Gray
Write-Host "    [10] Domain Admin Reuse:    Administrator:Corp@Admin2024     " -ForegroundColor Gray
Write-Host ""
Write-Host "  7 Flags Planted:                                               " -ForegroundColor Green
Write-Host "    - C:\flags\asrep_flag.txt          (VULN{4sr3p_r04st_cr4ck3d})" -ForegroundColor Green
Write-Host "    - C:\flags\kerberoast_flag.txt     (VULN{k3rb3r04st_svc_pwn3d})" -ForegroundColor Green
Write-Host "    - C:\flags\printnightmare_flag.txt (VULN{pr1ntn1ghtm4r3_dc})" -ForegroundColor Green
Write-Host "    - C:\flags\password_spray_flag.txt (VULN{p4ssw0rd_spr4y_h1t})" -ForegroundColor Green
Write-Host "    - C:\flags\dcsync_flag.txt         (VULN{dcs1nc_h4sh_dump3d})" -ForegroundColor Green
Write-Host "    - C:\flags\gpp_flag.txt            (VULN{gpp_p4ssw0rd_l34k})" -ForegroundColor Green
Write-Host "    - C:\flags\domain_flag.txt         (VULN{d0m41n_4dm1n_3mp1r3_f3ll})" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
