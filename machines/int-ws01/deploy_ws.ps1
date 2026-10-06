# ================================================================
# VulnCorp — Machine: int-ws01
# Windows 10 Vulnerable Workstation Deployment
#
# FOR AUTHORIZED / ISOLATED LAB USE ONLY
#
# Configures:
#   1. SMBv1 enabled
#   2. Windows Print Spooler enabled and running
#   3. Remote Desktop enabled
#   4. Network Level Authentication disabled
# ================================================================

#Requires -RunAsAdministrator

param(
    [string]$DomainName = "vulncorp.local",
    [string]$DCIP = "192.168.80.32",
    [string]$DomainAdmin = "VULNCORP\Administrator",
    [string]$DomainPassword = "Corp@Admin2024"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VulnCorp - int-ws01 Windows 10 Deployment" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# STEP 0 — Administrator Check
# ================================================================

Write-Host "[*] Checking Administrator privileges..." -ForegroundColor Yellow

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host "[-] ERROR: Run this script as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Running as Administrator." -ForegroundColor Green

# ================================================================
# STEP 1 — Windows Version Check
# ================================================================

Write-Host ""
Write-Host "[*] Checking Windows version..." -ForegroundColor Yellow

$os = Get-CimInstance Win32_OperatingSystem

Write-Host "[+] Operating System: $($os.Caption)" -ForegroundColor Green
Write-Host "[+] Version: $($os.Version)" -ForegroundColor Green

if ($os.Caption -notmatch "Windows 10") {
    Write-Warning "This deployment is intended for Windows 10."
}

# ================================================================
# STEP 2 — Check / Configure DNS
# ================================================================

Write-Host ""
Write-Host "[*] Checking connectivity to Domain Controller..." -ForegroundColor Yellow
Write-Host "[*] DC IP: $DCIP" -ForegroundColor Cyan

if (-not (Test-Connection -ComputerName $DCIP -Count 1 -Quiet)) {
    Write-Host "[-] ERROR: Cannot reach the Domain Controller at $DCIP." -ForegroundColor Red
    Write-Host "[-] Check the Hyper-V network connection." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Domain Controller is reachable." -ForegroundColor Green

# Find active network adapter
$adapter = Get-NetAdapter |
    Where-Object {$_.Status -eq "Up"} |
    Select-Object -First 1

if ($null -eq $adapter) {
    Write-Host "[-] ERROR: No active network adapter found." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Active adapter: $($adapter.Name)" -ForegroundColor Cyan

# Set DNS to the Domain Controller
Write-Host "[*] Setting DNS server to Domain Controller..." -ForegroundColor Yellow

Set-DnsClientServerAddress `
    -InterfaceIndex $adapter.ifIndex `
    -ServerAddresses $DCIP

Write-Host "[+] DNS configured to $DCIP." -ForegroundColor Green

# ================================================================
# STEP 3 — Domain Join
# ================================================================

$currentDomain = (Get-CimInstance Win32_ComputerSystem).Domain

if ($currentDomain -ne $DomainName) {

    Write-Host ""
    Write-Host "[*] Machine is not joined to $DomainName." -ForegroundColor Yellow
    Write-Host "[*] Joining domain..." -ForegroundColor Yellow

    try {

        $securePassword = ConvertTo-SecureString `
            $DomainPassword `
            -AsPlainText `
            -Force

        $credential = New-Object `
            System.Management.Automation.PSCredential(
                $DomainAdmin,
                $securePassword
            )

        Add-Computer `
            -DomainName $DomainName `
            -Credential $credential `
            -Force `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "[+] Successfully joined $DomainName." -ForegroundColor Green
        Write-Host ""
        Write-Host "[!] Windows must restart to complete the domain join." -ForegroundColor Yellow

        $restart = Read-Host "Restart now? (Y/N)"

        if ($restart -match "^[Yy]$") {
            Restart-Computer -Force
        }

        exit
    }
    catch {
        Write-Host ""
        Write-Host "[-] Domain join failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}
else {

    Write-Host ""
    Write-Host "[+] Already joined to domain: $currentDomain" -ForegroundColor Green
}

# ================================================================
# STEP 4 — SMBv1
# ================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[1/3] Configuring SMBv1" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "[*] Enabling SMB1 Windows feature..." -ForegroundColor Yellow

try {

    Enable-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol `
        -All `
        -NoRestart `
        -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[+] SMBv1 Windows feature enabled." -ForegroundColor Green
}
catch {

    Write-Warning "Could not enable SMB1 Windows feature."
}

# Enable SMB1 server protocol
try {

    Set-SmbServerConfiguration `
        -EnableSMB1Protocol $true `
        -Force `
        -ErrorAction SilentlyContinue

    Write-Host "[+] SMBv1 server protocol enabled." -ForegroundColor Green
}
catch {

    Write-Warning "SMB server configuration command was unavailable."
}

# ================================================================
# STEP 5 — Windows Print Spooler
# ================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[2/3] Configuring Windows Print Spooler" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "[*] Setting Print Spooler startup type to Automatic..." -ForegroundColor Yellow

Set-Service `
    -Name Spooler `
    -StartupType Automatic

Write-Host "[*] Starting Print Spooler..." -ForegroundColor Yellow

Start-Service `
    -Name Spooler `
    -ErrorAction SilentlyContinue

$spooler = Get-Service -Name Spooler

if ($spooler.Status -eq "Running") {

    Write-Host "[+] Windows Print Spooler is RUNNING." -ForegroundColor Green
}
else {

    Write-Host "[-] WARNING: Print Spooler is not running." -ForegroundColor Red
}

# ================================================================
# STEP 6 — Remote Desktop Without NLA
# ================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[3/3] Configuring Remote Desktop" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "[*] Enabling Remote Desktop..." -ForegroundColor Yellow

$terminalServerPath =
    "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"

Set-ItemProperty `
    -Path $terminalServerPath `
    -Name "fDenyTSConnections" `
    -Type DWord `
    -Value 0

Write-Host "[+] Remote Desktop enabled." -ForegroundColor Green

Write-Host "[*] Disabling Network Level Authentication..." -ForegroundColor Yellow

$rdpTcpPath =
    "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

Set-ItemProperty `
    -Path $rdpTcpPath `
    -Name "UserAuthentication" `
    -Type DWord `
    -Value 0

Write-Host "[+] Network Level Authentication disabled." -ForegroundColor Green

# Enable Remote Desktop firewall rules
Write-Host "[*] Enabling Remote Desktop firewall rules..." -ForegroundColor Yellow

Enable-NetFirewallRule `
    -DisplayGroup "Remote Desktop" `
    -ErrorAction SilentlyContinue

Write-Host "[+] Remote Desktop firewall rules enabled." -ForegroundColor Green

# ================================================================
# STEP 7 — Verification
# ================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# SMBv1
Write-Host ""
Write-Host "[*] SMBv1 status:" -ForegroundColor Yellow

$smbFeature = Get-WindowsOptionalFeature `
    -Online `
    -FeatureName SMB1Protocol

Write-Host "    Windows Feature: $($smbFeature.State)"

try {

    $smbConfig = Get-SmbServerConfiguration

    Write-Host "    SMB1 Server: $($smbConfig.EnableSMB1Protocol)"
}
catch {

    Write-Host "    SMB1 Server: Unable to query"
}

# Print Spooler
Write-Host ""
Write-Host "[*] Print Spooler status:" -ForegroundColor Yellow

$spooler = Get-Service -Name Spooler

Write-Host "    Status: $($spooler.Status)"
Write-Host "    Startup: $($spooler.StartType)"

# RDP
Write-Host ""
Write-Host "[*] Remote Desktop status:" -ForegroundColor Yellow

$rdp = Get-ItemProperty `
    -Path $terminalServerPath `
    -Name "fDenyTSConnections"

$nla = Get-ItemProperty `
    -Path $rdpTcpPath `
    -Name "UserAuthentication"

if ($rdp.fDenyTSConnections -eq 0) {

    Write-Host "    RDP: ENABLED" -ForegroundColor Green
}
else {

    Write-Host "    RDP: DISABLED" -ForegroundColor Red
}

if ($nla.UserAuthentication -eq 0) {

    Write-Host "    NLA: DISABLED" -ForegroundColor Green
}
else {

    Write-Host "    NLA: ENABLED" -ForegroundColor Red
}

# ================================================================
# COMPLETION
# ================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " int-ws01 DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host ""
Write-Host "Configured vulnerabilities:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  [1] SMBv1 enabled"
Write-Host "  [2] Windows Print Spooler enabled/running"
Write-Host "  [3] Remote Desktop enabled"
Write-Host "  [4] Network Level Authentication disabled"
Write-Host ""

Write-Host "Domain : $DomainName"
Write-Host "DC IP  : $DCIP"
Write-Host ""

Write-Host "[!] A restart is recommended after SMBv1 installation." -ForegroundColor Yellow
Write-Host ""

$restart = Read-Host "Restart the computer now? (Y/N)"

if ($restart -match "^[Yy]$") {

    Write-Host "[*] Restarting..." -ForegroundColor Yellow
    Restart-Computer -Force
}
else {

    Write-Host "[!] Restart skipped. Restart manually before testing." -ForegroundColor Yellow
}