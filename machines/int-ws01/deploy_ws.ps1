#Requires -RunAsAdministrator

<#
VulnCorp — Machine 12: int-ws01
Windows Server 2019 Vulnerable Member Server

Purpose:
    Configure a Windows Server 2019 machine as a domain-joined
    vulnerable member server for the VulnCorp/ASPER lab.

IMPORTANT:
    - This machine is NOT a Domain Controller.
    - The existing DC is assumed to be:
        Domain: vulncorp.local
        DC IP: 192.168.80.32
    - The machine may use DHCP. No static IP is configured here.

Vulnerabilities / services configured:
    1. SMBv1
    2. SMB signing disabled
    3. Print Spooler enabled
    4. Remote Desktop enabled
    5. Network Level Authentication disabled

Run:
    PowerShell as Administrator
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\deploy_ws.ps1

The script may reboot the machine during domain joining.
After reboot, run the script again if requested.
#>

[CmdletBinding()]
param(
    [string]$DomainName = "vulncorp.local",

    [string]$DCIP = "192.168.80.32",

    [string]$DomainAdmin = "VULNCORP\Administrator",

    [string]$DomainPassword = "Corp@Admin2024"
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Success {
    param(
        [string]$Message
    )

    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param(
        [string]$Message
    )

    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Test-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "       VULNCORP - int-ws01 Deployment" -ForegroundColor Cyan
Write-Host "       Windows Server 2019 Vulnerable Member Server" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""

# ------------------------------------------------------------
# Step 1 - Administrator check
# ------------------------------------------------------------

Write-Step "STEP 1 - Checking Administrator privileges"

if (-not (Test-Administrator)) {
    Write-Error "Please run PowerShell as Administrator."
    exit 1
}

Write-Success "PowerShell is running with Administrator privileges."

# ------------------------------------------------------------
# Step 2 - OS check
# ------------------------------------------------------------

Write-Step "STEP 2 - Checking Windows version"

$os = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System : $($os.Caption)"
Write-Host "Version          : $($os.Version)"
Write-Host "Build            : $($os.BuildNumber)"

if ($os.Caption -notmatch "Windows Server 2019") {
    Write-WarningMessage "This script is intended for Windows Server 2019."
    Write-WarningMessage "Detected: $($os.Caption)"

    $continue = Read-Host "Continue anyway? (Y/N)"

    if ($continue -notmatch "^[Yy]$") {
        Write-Host "Deployment cancelled."
        exit 1
    }
}

Write-Success "Operating system check completed."

# ------------------------------------------------------------
# Step 3 - Display current network configuration
# ------------------------------------------------------------

Write-Step "STEP 3 - Checking current network configuration"

Write-Host ""
Write-Host "Current IPv4 configuration:"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*"
    } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Current DNS configuration:"
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Select-Object InterfaceAlias, ServerAddresses |
    Format-Table -AutoSize

Write-WarningMessage "No static IP address will be configured by this script."

# ------------------------------------------------------------
# Step 4 - Test connectivity to Domain Controller
# ------------------------------------------------------------

Write-Step "STEP 4 - Testing connectivity to Domain Controller"

Write-Host "DC IP: $DCIP"

$pingResult = Test-Connection -ComputerName $DCIP -Count 2 -Quiet

if ($pingResult) {
    Write-Success "The Domain Controller responds to ICMP."
}
else {
    Write-WarningMessage "The DC did not respond to ping."
    Write-WarningMessage "Continuing to test required services..."
}

# Test DNS port
try {
    $dnsTest = Test-NetConnection `
        -ComputerName $DCIP `
        -Port 53 `
        -WarningAction SilentlyContinue

    if ($dnsTest.TcpTestSucceeded) {
        Write-Success "TCP port 53 is reachable on the DC."
    }
    else {
        Write-WarningMessage "TCP port 53 could not be reached on the DC."
    }
}
catch {
    Write-WarningMessage "DNS connectivity test could not be completed."
}

# ------------------------------------------------------------
# Step 5 - Test domain DNS resolution
# ------------------------------------------------------------

Write-Step "STEP 5 - Testing domain name resolution"

try {
    $domainResolution = Resolve-DnsName `
        -Name $DomainName `
        -ErrorAction Stop

    Write-Success "$DomainName resolves successfully."

    $domainResolution |
        Select-Object Name, Type, IPAddress |
        Format-Table -AutoSize
}
catch {
    Write-WarningMessage "Unable to resolve $DomainName using the current DNS configuration."

    Write-Host ""
    Write-Host "The Windows Server must be able to resolve the domain before"
    Write-Host "the domain join can succeed."
    Write-Host ""

    Write-WarningMessage "Make sure the network/DHCP DNS configuration points to the DC:"
    Write-Host "    $DCIP" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Deployment cannot continue until domain DNS works." -ForegroundColor Red

    exit 1
}

# ------------------------------------------------------------
# Step 6 - Check domain membership
# ------------------------------------------------------------

Write-Step "STEP 6 - Checking domain membership"

$computerSystem = Get-CimInstance Win32_ComputerSystem

Write-Host "Computer Name : $($computerSystem.Name)"
Write-Host "Domain        : $($computerSystem.Domain)"
Write-Host "Part of Domain: $($computerSystem.PartOfDomain)"

if ($computerSystem.PartOfDomain -and
    $computerSystem.Domain -ieq $DomainName) {

    Write-Success "This machine is already joined to $DomainName."
}
else {

    Write-WarningMessage "This machine is not yet joined to $DomainName."

    Write-Step "STEP 7 - Joining the VulnCorp domain"

    Write-Host "Domain: $DomainName"
    Write-Host "Domain Controller: $DCIP"
    Write-Host ""

    $securePassword = ConvertTo-SecureString `
        $DomainPassword `
        -AsPlainText `
        -Force

    $credential = New-Object `
        System.Management.Automation.PSCredential(
            $DomainAdmin,
            $securePassword
        )

    try {

        Add-Computer `
            -DomainName $DomainName `
            -Credential $credential `
            -Force `
            -ErrorAction Stop

        Write-Success "Domain join command completed successfully."

        Write-WarningMessage "The computer must restart to complete the domain join."

        $restart = Read-Host "Restart now? (Y/N)"

        if ($restart -match "^[Yy]$") {

            Write-Host ""
            Write-Host "Restarting computer..." -ForegroundColor Yellow

            Start-Sleep -Seconds 5

            Restart-Computer -Force
            exit
        }
        else {

            Write-WarningMessage "Restart was skipped."
            Write-WarningMessage "Restart the computer manually before continuing."

            exit 0
        }

    }
    catch {

        Write-Error "Domain join failed."
        Write-Error $_.Exception.Message

        Write-Host ""
        Write-Host "Check the following:" -ForegroundColor Yellow
        Write-Host "  1. The DC is reachable at $DCIP"
        Write-Host "  2. DNS can resolve $DomainName"
        Write-Host "  3. The Domain Administrator credentials are correct"
        Write-Host "  4. Both machines are on the same lab network"
        Write-Host ""

        exit 1
    }
}

# ------------------------------------------------------------
# Step 8 - SMBv1
# ------------------------------------------------------------

Write-Step "STEP 8 - Configuring SMBv1"

Write-Host "Checking SMB1 optional feature..."

try {

    $smbFeature = Get-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol `
        -ErrorAction Stop

    Write-Host "Current SMB1 state: $($smbFeature.State)"

    if ($smbFeature.State -ne "Enabled") {

        Write-Host "Enabling SMB1Protocol..." -ForegroundColor Yellow

        Enable-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -All `
            -NoRestart `
            -ErrorAction Stop

        Write-Success "SMBv1 Windows feature enabled."
    }
    else {

        Write-Success "SMBv1 Windows feature is already enabled."
    }

}
catch {

    Write-WarningMessage "Could not configure the SMB1 Windows feature."
    Write-WarningMessage $_.Exception.Message
}

# Configure SMB server SMB1 support
try {

    $smbServerConfig = Get-SmbServerConfiguration

    if ($smbServerConfig.EnableSMB1Protocol -ne $true) {

        Set-SmbServerConfiguration `
            -EnableSMB1Protocol $true `
            -Force `
            -ErrorAction Stop

        Write-Success "SMB server SMBv1 support enabled."
    }
    else {

        Write-Success "SMB server SMBv1 support is already enabled."
    }

}
catch {

    Write-WarningMessage "Could not configure SMB server SMBv1 support."
    Write-WarningMessage $_.Exception.Message
}

# ------------------------------------------------------------
# Step 9 - Disable SMB signing
# ------------------------------------------------------------

Write-Step "STEP 9 - Disabling SMB signing"

try {

    Set-SmbServerConfiguration `
        -RequireSecuritySignature $false `
        -Force `
        -ErrorAction Stop

    Write-Success "SMB server signing requirement disabled."

}
catch {

    Write-WarningMessage "Could not change SMB signing configuration."
    Write-WarningMessage $_.Exception.Message
}

# ------------------------------------------------------------
# Step 10 - Print Spooler
# ------------------------------------------------------------

Write-Step "STEP 10 - Configuring Windows Print Spooler"

try {

    Set-Service `
        -Name Spooler `
        -StartupType Automatic `
        -ErrorAction Stop

    Start-Service `
        -Name Spooler `
        -ErrorAction Stop

    Write-Success "Print Spooler is configured as Automatic and Running."

}
catch {

    Write-WarningMessage "Could not configure the Print Spooler service."
    Write-WarningMessage $_.Exception.Message
}

# ------------------------------------------------------------
# Step 11 - Remote Desktop
# ------------------------------------------------------------

Write-Step "STEP 11 - Configuring Remote Desktop"

try {

    # Enable Remote Desktop
    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" `
        -Value 0 `
        -Type DWord `
        -Force

    Write-Success "Remote Desktop has been enabled."

}
catch {

    Write-WarningMessage "Could not enable Remote Desktop."
    Write-WarningMessage $_.Exception.Message
}

# ------------------------------------------------------------
# Step 12 - Disable Network Level Authentication
# ------------------------------------------------------------

Write-Step "STEP 12 - Disabling Network Level Authentication"

try {

    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -Name "UserAuthentication" `
        -Value 0 `
        -Type DWord `
        -Force

    Write-Success "Network Level Authentication has been disabled."

}
catch {

    Write-WarningMessage "Could not disable Network Level Authentication."
    Write-WarningMessage $_.Exception.Message
}

# ------------------------------------------------------------
# Step 13 - Enable Remote Desktop firewall rules
# ------------------------------------------------------------

Write-Step "STEP 13 - Enabling Remote Desktop firewall rules"

try {

    Enable-NetFirewallRule `
        -DisplayGroup "Remote Desktop" `
        -ErrorAction Stop

    Write-Success "Remote Desktop firewall rules enabled."

}
catch {

    Write-WarningMessage "Could not enable Remote Desktop firewall rules."
    Write-WarningMessage $_.Exception.Message
}

# ------------------------------------------------------------
# Step 14 - Verification
# ------------------------------------------------------------

Write-Step "STEP 14 - Verifying deployment"

Write-Host ""
Write-Host "===== DOMAIN =====" -ForegroundColor White

$computerSystem = Get-CimInstance Win32_ComputerSystem

Write-Host "Computer Name : $($computerSystem.Name)"
Write-Host "Domain        : $($computerSystem.Domain)"
Write-Host "Part of Domain: $($computerSystem.PartOfDomain)"

Write-Host ""
Write-Host "===== SMBv1 =====" -ForegroundColor White

try {

    $smbFeature = Get-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol

    Write-Host "Windows SMB1 Feature : $($smbFeature.State)"

}
catch {

    Write-WarningMessage "Unable to read SMB1 feature state."
}

try {

    $smbConfig = Get-SmbServerConfiguration

    Write-Host "SMB1 Server Protocol : $($smbConfig.EnableSMB1Protocol)"
    Write-Host "SMB Signing Required : $($smbConfig.RequireSecuritySignature)"

}
catch {

    Write-WarningMessage "Unable to read SMB server configuration."
}

Write-Host ""
Write-Host "===== PRINT SPOOLER =====" -ForegroundColor White

try {

    $spooler = Get-Service -Name Spooler

    Write-Host "Status     : $($spooler.Status)"
    Write-Host "Start Type : $($spooler.StartType)"

}
catch {

    Write-WarningMessage "Unable to read Print Spooler status."
}

Write-Host ""
Write-Host "===== REMOTE DESKTOP =====" -ForegroundColor White

try {

    $rdp = Get-ItemProperty `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
        -Name fDenyTSConnections

    $nla = Get-ItemProperty `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -Name UserAuthentication

    Write-Host "RDP Disabled Value : $($rdp.fDenyTSConnections)"
    Write-Host "NLA Value          : $($nla.UserAuthentication)"

}
catch {

    Write-WarningMessage "Unable to read Remote Desktop configuration."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "              DEPLOYMENT CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Configured components:" -ForegroundColor Cyan
Write-Host "  [*] Domain membership"
Write-Host "  [*] SMBv1"
Write-Host "  [*] SMB signing disabled"
Write-Host "  [*] Print Spooler"
Write-Host "  [*] Remote Desktop"
Write-Host "  [*] NLA disabled"
Write-Host ""

Write-WarningMessage "This machine is intentionally vulnerable and should remain"
Write-WarningMessage "isolated inside the authorized ASPER lab environment."

Write-Host ""
Write-Host "A restart is recommended to ensure all configuration changes"
Write-Host "are fully applied." -ForegroundColor Yellow

$finalRestart = Read-Host "Restart now? (Y/N)"

if ($finalRestart -match "^[Yy]$") {

    Write-Host ""
    Write-Host "Restarting..." -ForegroundColor Yellow

    Start-Sleep -Seconds 5

    Restart-Computer -Force
}
else {

    Write-Host ""
    Write-Host "Restart skipped. Please restart this machine manually later."
}