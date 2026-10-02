# ================================================================
# VulnCorp — Machine 12: int-ws01 (Domain-Joined Workstation)
# Automated Windows Vulnerability Deployment Script
# Run this in PowerShell as Administrator on Windows 10/11
# ================================================================
# ⚠️  IP Note: Change 192.168.1.60 and 192.168.1.10 (DC) to
#     match your lab network layout before running this script.
# ================================================================

param(
    [string]$DomainName = "vulncorp.local",
    [string]$DCIP = "192.168.1.10",
    [string]$DomainAdmin = "VULNCORP\Administrator",
    [string]$DomainPassword = "Corp@Admin2024"
)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  VulnCorp Workstation (int-ws01) Deploy     " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# ── Step 0: Pre-flight Checks ────────────────────────────────────
Write-Host "[*] Performing pre-flight checks..." -ForegroundColor Yellow

# 1. Administrator Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[-] Error: This script must be run as Administrator. Please open an elevated PowerShell prompt." -ForegroundColor Red
    Exit
}

# 2. Windows Edition Check
$edition = (Get-ComputerInfo).WindowsProductName
$isHomeEdition = ($edition -match "Home")
if ($isHomeEdition) {
    Write-Host "[!] Warning: Windows Home edition detected ($edition)." -ForegroundColor Yellow
    Write-Host "[!] Active Directory Domain Join and RDP are not supported on Home edition. These steps will be skipped." -ForegroundColor Yellow
    Write-Host "[!] The machine will be configured as a standalone workgroup computer." -ForegroundColor Yellow
}

# 3. Connectivity & DNS Check (Skip if Home edition, as we won't join the domain)
if (-not $isHomeEdition) {
    Write-Host "[*] Checking connectivity to Domain Controller ($DCIP)..." -ForegroundColor Yellow
    if (-not (Test-Connection -ComputerName $DCIP -Count 1 -Quiet)) {
        Write-Host "[-] Error: Cannot reach Domain Controller at $DCIP. Check network connectivity." -ForegroundColor Red
        Exit
    }

    Write-Host "[*] Checking DNS resolution for $DomainName..." -ForegroundColor Yellow
    try {
        $dns = Resolve-DnsName -Name $DomainName -Server $DCIP -ErrorAction Stop
        if (-not $dns) { throw "No records returned" }
    } catch {
        Write-Host "[-] Error: Cannot resolve $DomainName using DNS server $DCIP. Check AD DNS configuration." -ForegroundColor Red
        Exit
    }
}

Write-Host "[+] Pre-flight checks passed." -ForegroundColor Green

# ── Step 1: Join Domain (if not already joined) ──────────────────
if ($isHomeEdition) {
    Write-Host "[!] Skipping Domain Join (Not supported on Windows Home)" -ForegroundColor Yellow
} else {
    $currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
    if ($currentDomain -ne $DomainName) {
        Write-Host "[*] Setting DNS to Domain Controller ($DCIP)..." -ForegroundColor Yellow
        $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DCIP
    
        try {
            Write-Host "[*] Joining domain $DomainName..." -ForegroundColor Yellow
            $secPass = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential($DomainAdmin, $secPass)
        
            Add-Computer -DomainName $DomainName -Credential $cred -OUPath "OU=VulnCorp Users,DC=vulncorp,DC=local" -Force -ErrorAction Stop
        
            Write-Host "[!] Rebooting to complete domain join. Re-run this script after reboot." -ForegroundColor Green
            Restart-Computer -Force
            Exit
        } catch {
            Write-Host "[-] Failed to join domain. Error: $_" -ForegroundColor Red
            Write-Host "Press any key to exit without restarting..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Exit
        }
    }
    Write-Host "[+] Already joined to domain: $currentDomain" -ForegroundColor Green
}

# ── Step 2: Create Weak Local Admin ──────────────────────────────
Write-Host "[*] Creating weak local admin account..." -ForegroundColor Yellow
try {
    net user ws_admin "Desktop@2024" /add /Y 2>$null
    net localgroup Administrators ws_admin /add 2>$null
    Write-Host "[+] Local admin created: ws_admin / Desktop@2024" -ForegroundColor Green
} catch {
    Write-Host "[-] ws_admin may already exist" -ForegroundColor Gray
}

# ── Step 3: Enable SMBv1 (EternalBlue — CVE-2017-0144) ──────────
Write-Host "[*] Enabling SMBv1 protocol (EternalBlue vector)..." -ForegroundColor Yellow
Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue
Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
Write-Host "[+] SMBv1 enabled" -ForegroundColor Green

# ── Step 4: Disable SMB Signing ──────────────────────────────────
Write-Host "[*] Disabling SMB signing (NTLM relay vector)..." -ForegroundColor Yellow
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
Write-Host "[+] SMB signing disabled" -ForegroundColor Green

# ── Step 5: Enable Print Spooler (PrintNightmare — CVE-2021-34527)
Write-Host "[*] Enabling Print Spooler (PrintNightmare vector)..." -ForegroundColor Yellow
Set-Service -Name Spooler -StartupType Automatic
Start-Service -Name Spooler -ErrorAction SilentlyContinue
Write-Host "[+] Print Spooler running" -ForegroundColor Green

# ── Step 6: Unquoted Service Path ────────────────────────────────
Write-Host "[*] Creating unquoted service path vulnerability..." -ForegroundColor Yellow
$svcPath = "C:\Program Files\VulnCorp\Monitoring Agent"
New-Item -ItemType Directory -Force -Path $svcPath | Out-Null

# Create a dummy executable
Set-Content "$svcPath\monitor.exe" "REM VulnCorp Monitoring Agent Stub"

# Register service with unquoted path (intentional vulnerability)
sc.exe create "VulnCorpMonitor" binPath= "C:\Program Files\VulnCorp\Monitoring Agent\monitor.exe" start= auto DisplayName= "VulnCorp Monitoring Agent" 2>$null
Write-Host "[+] Unquoted service path created: VulnCorp Monitoring Agent" -ForegroundColor Green

# ── Step 7: AlwaysInstallElevated ────────────────────────────────
Write-Host "[*] Setting AlwaysInstallElevated (MSI privesc)..." -ForegroundColor Yellow
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -Value 1 -Type DWord

New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -Value 1 -Type DWord
Write-Host "[+] AlwaysInstallElevated set in HKLM and HKCU" -ForegroundColor Green

# ── Step 8: Enable RDP Without NLA ───────────────────────────────
if ($isHomeEdition) {
    Write-Host "[!] Skipping RDP Configuration (Not supported on Windows Home)" -ForegroundColor Yellow
} else {
    Write-Host "[*] Enabling RDP without NLA..." -ForegroundColor Yellow
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Write-Host "[+] RDP enabled without NLA on port 3389" -ForegroundColor Green
}

# ── Step 9: Enable LLMNR and NetBIOS ─────────────────────────────
Write-Host "[*] Ensuring LLMNR and NetBIOS are enabled (Responder vector)..." -ForegroundColor Yellow
# LLMNR: Remove the disable key if it exists (default = enabled)
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue
# NetBIOS: Set to default (enabled)
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
foreach ($a in $adapters) {
    $a.SetTcpipNetbios(0) | Out-Null  # 0 = Default (enabled via DHCP)
}
Write-Host "[+] LLMNR and NetBIOS Name Service enabled" -ForegroundColor Green

# ── Step 10: Plant Stored Credentials ────────────────────────────
Write-Host "[*] Planting stored credentials (browser dump simulation)..." -ForegroundColor Yellow

# Simulate John Doe's profile with saved passwords
$profilePath = "C:\Users\john.doe\Documents"
New-Item -ItemType Directory -Force -Path $profilePath | Out-Null

Set-Content "$profilePath\saved_passwords.txt" @"
# VulnCorp Saved Credentials — DO NOT SHARE
# ==========================================
# Found in browser credential store / password manager

Domain Controller (192.168.1.10):
  Username: john.doe
  Password: Corp@Admin2024
  Protocol: RDP / SMB

Domain Controller (192.168.1.10):
  Username: svc_backup
  Password: Backup@Svc2024
  Protocol: LDAP (Service Account)

ERP Server (192.168.1.20):
  Username: admin
  Password: admin123
  Protocol: HTTP

File Server (192.168.1.40):
  Username: fileuser
  Password: File@User2024
  Protocol: SMB

Backup Server (192.168.1.50):
  Username: backupadmin
  Password: backup123
  Protocol: rsync / SSH
"@

# WiFi profile with domain creds
Set-Content "$profilePath\wifi_enterprise.xml" @"
<?xml version="1.0"?>
<WLANProfile>
  <name>VulnCorp-Internal</name>
  <SSIDConfig><SSID><name>VulnCorp-Internal</name></SSID></SSIDConfig>
  <MSM><security>
    <EAPConfig>
      <Identity>john.doe</Identity>
      <Password>Corp@Admin2024</Password>
    </EAPConfig>
  </security></MSM>
</WLANProfile>
"@

Write-Host "[+] Stored credentials planted in john.doe profile" -ForegroundColor Green

# ── Step 11: Create Shared Folder (SMB) ──────────────────────────
Write-Host "[*] Creating SMB share with sensitive files..." -ForegroundColor Yellow
$sharePath = "C:\Shares\Public"
New-Item -ItemType Directory -Force -Path $sharePath | Out-Null

Set-Content "$sharePath\IT_Notes.txt" @"
IT Team Notes — Internal Use Only
==================================
DC Admin Password: Corp@Admin2024
WiFi PSK: VulnCorp2024!
VPN: Connect via rz-vpn01 (172.16.0.20)
Backup user: svc_backup / Backup@Svc2024
"@

New-SmbShare -Name "Public" -Path $sharePath -FullAccess "Everyone" -ErrorAction SilentlyContinue
Write-Host "[+] SMB share 'Public' created" -ForegroundColor Green

# ── Step 12: Plant Flags ─────────────────────────────────────────
Write-Host "[*] Planting flags..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "C:\flags" | Out-Null
"VULN{3t3rn4l_blu3_w0rkst4t10n}" | Set-Content "C:\flags\eternalblue_flag.txt"
"VULN{st0r3d_cr3ds_p1vot}"       | Set-Content "C:\flags\creds_flag.txt"
"VULN{w0rkst4t10n_4dm1n_pwn3d}"  | Set-Content "C:\flags\admin_flag.txt"
Write-Host "[+] Flags planted in C:\flags\" -ForegroundColor Green

# ── Step 13: Disable Windows Firewall (for lab) ──────────────────
Write-Host "[*] Disabling Windows Firewall (lab environment)..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "[+] Firewall disabled" -ForegroundColor Green

# ── Step 14: Disable Windows Defender (for lab) ──────────────────
Write-Host "[*] Disabling Windows Defender (lab environment)..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force -ErrorAction SilentlyContinue
Write-Host "[+] Windows Defender disabled" -ForegroundColor Green

Write-Host "" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Workstation Setup COMPLETE!                " -ForegroundColor Green
Write-Host "  Hostname: $env:COMPUTERNAME                " -ForegroundColor Cyan
Write-Host "  Domain:   $DomainName                      " -ForegroundColor Cyan
Write-Host "  Local Admin: ws_admin / Desktop@2024       " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Vulnerabilities Configured:" -ForegroundColor Yellow
Write-Host "    [1] EternalBlue (SMBv1 enabled)"
Write-Host "    [2] Stored credentials (john.doe profile)"
Write-Host "    [3] PrintNightmare (Print Spooler running)"
Write-Host "    [4] Unquoted service path (VulnCorpMonitor)"
Write-Host "    [5] AlwaysInstallElevated (MSI privesc)"
Write-Host "    [6] LLMNR/NetBIOS poisoning (Responder)"
Write-Host "    [7] Weak local admin (ws_admin/Desktop@2024)"
Write-Host "    [8] RDP without NLA (port 3389)"
Write-Host ""
