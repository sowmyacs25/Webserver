#Requires -RunAsAdministrator

<#
VulnCorp - Machine 12: int-ws01
Windows Server 2019 Vulnerable Member Server

PURPOSE
-------
Configure a Windows Server 2019 machine as a vulnerable
domain-joined member server for the VulnCorp / ASPER lab.

DOMAIN
------
Domain Name       : vulncorp.local
Domain Controller : 192.168.80.32
NetBIOS Domain    : VULNCORP

IMPORTANT
---------
- This machine is NOT a Domain Controller.
- The machine IP remains DHCP.
- DNS is automatically configured to use the DC.
- Run this script from an elevated PowerShell window.
- The script is safe to run again after reboot.

CONFIGURED LAB SERVICES / VULNERABILITIES
------------------------------------------
1. SMBv1 enabled
2. SMB signing disabled
3. Print Spooler enabled
4. Remote Desktop enabled
5. Network Level Authentication disabled
6. RDP firewall rules enabled
7. LLMNR enabled
8. NetBIOS over TCP/IP enabled
9. Weak local administrator account
10. Unquoted service path
11. AlwaysInstallElevated
12. Stored credentials
13. SMB vulnerable share
14. Windows Firewall disabled
15. Windows Defender disabled

AUTHORIZED LAB USE ONLY
#>

[CmdletBinding()]
param(
    [string]$DomainName = "vulncorp.local",
    [string]$DCIP = "192.168.80.32",
    [string]$DomainAdmin = "VULNCORP\Administrator",
    [string]$DomainPassword = "Corp@Admin2024"
)

$ErrorActionPreference = "Stop"

# ============================================================
# FUNCTIONS
# ============================================================

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)

    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)

    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)

    Write-Host "[X] $Message" -ForegroundColor Red
}

function Test-Administrator {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-PrimaryNetworkAdapter {

    $adapter = Get-NetAdapter |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.HardwareInterface -eq $true
        } |
        Sort-Object ifIndex |
        Select-Object -First 1

    return $adapter
}

# ============================================================
# START
# ============================================================

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "             VULNCORP - int-ws01 DEPLOYMENT" -ForegroundColor Cyan
Write-Host "        Windows Server 2019 Vulnerable Member Server" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""

# ============================================================
# STEP 1 - ADMINISTRATOR
# ============================================================

Write-Step "STEP 1 - Checking Administrator privileges"

if (-not (Test-Administrator)) {

    Write-Fail "PowerShell is not running as Administrator."
    Write-Host "Right-click PowerShell and select 'Run as administrator'."
    exit 1
}

Write-Success "PowerShell is running as Administrator."

# ============================================================
# STEP 2 - WINDOWS VERSION
# ============================================================

Write-Step "STEP 2 - Checking Windows version"

$os = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System : $($os.Caption)"
Write-Host "Version          : $($os.Version)"
Write-Host "Build            : $($os.BuildNumber)"

if ($os.Caption -notmatch "Windows Server 2019") {

    Write-Warn "This script is intended for Windows Server 2019."
    Write-Warn "Detected: $($os.Caption)"

    $answer = Read-Host "Continue anyway? (Y/N)"

    if ($answer -notmatch "^[Yy]$") {

        Write-Host "Deployment cancelled."
        exit 1
    }
}

Write-Success "Operating system check completed."

# ============================================================
# STEP 3 - NETWORK ADAPTER
# ============================================================

Write-Step "STEP 3 - Detecting network adapter"

$adapter = Get-PrimaryNetworkAdapter

if (-not $adapter) {

    Write-Fail "No active physical network adapter was found."
    Write-Host "Check the VM network adapter and try again."
    exit 1
}

Write-Host "Adapter : $($adapter.Name)"
Write-Host "Status  : $($adapter.Status)"
Write-Host "Index   : $($adapter.ifIndex)"

Write-Success "Network adapter detected."

# ============================================================
# STEP 4 - KEEP IP DHCP + SET DNS TO DC
# ============================================================

Write-Step "STEP 4 - Verifying DHCP IP and configuring Domain Controller DNS"

Write-Host "The server IP will remain DHCP."
Write-Host "DNS will be configured to:"
Write-Host "    $DCIP"

try {

    # Do not disturb a valid DHCP lease. Only repair DHCP if there is
    # no usable IPv4 address or the machine has fallen back to APIPA.
    $currentIPv4 = Get-NetIPAddress `
        -InterfaceIndex $adapter.ifIndex `
        -AddressFamily IPv4 `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*"
        } |
        Select-Object -First 1

    if (-not $currentIPv4) {

        Write-Warn "No usable IPv4 address detected. Repairing DHCP..."

        Set-NetIPInterface `
            -InterfaceIndex $adapter.ifIndex `
            -AddressFamily IPv4 `
            -Dhcp Enabled `
            -ErrorAction Stop

        ipconfig /renew | Out-Host
        Start-Sleep -Seconds 5

        $currentIPv4 = Get-NetIPAddress `
            -InterfaceIndex $adapter.ifIndex `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.IPAddress -notlike "127.*" -and
                $_.IPAddress -notlike "169.254.*"
            } |
            Select-Object -First 1
    }

    if (-not $currentIPv4) {
        throw "No valid DHCP IPv4 address is available. The VM network/DHCP must be fixed before deployment."
    }

    Write-Success "Usable IPv4 address: $($currentIPv4.IPAddress)"

    # Configure AD DNS without changing the valid IP lease.
    Set-DnsClientServerAddress `
        -InterfaceIndex $adapter.ifIndex `
        -ServerAddresses $DCIP `
        -ErrorAction Stop

    Write-Success "DNS is configured to $DCIP."

}
catch {

    Write-Fail "Could not configure the network/DNS."

    Write-Host ""
    Write-Host "Error:"
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}

# ============================================================
# STEP 5 - FLUSH DNS
# ============================================================

Write-Step "STEP 5 - Refreshing DNS"

try {

    ipconfig /flushdns | Out-Host

    Write-Success "DNS cache flushed."

}
catch {

    Write-Warn "Could not flush DNS cache."
}

# ============================================================
# STEP 6 - TEST DC CONNECTIVITY
# ============================================================

Write-Step "STEP 6 - Testing Domain Controller connectivity"

Write-Host "Domain Controller : $DCIP"

try {

    $ping = Test-Connection `
        -ComputerName $DCIP `
        -Count 2 `
        -Quiet `
        -ErrorAction SilentlyContinue

    if ($ping) {

        Write-Success "Domain Controller responds to ping."

    }
    else {

        Write-Warn "Domain Controller did not respond to ping."
        Write-Warn "Continuing because ICMP may be blocked."
    }

}
catch {

    Write-Warn "Ping test could not be completed."
}

# ============================================================
# STEP 7 - TEST REQUIRED AD PORTS
# ============================================================

Write-Step "STEP 7 - Testing Active Directory services"

$requiredPorts = @(
    53,
    88,
    135,
    139,
    389,
    445
)

foreach ($port in $requiredPorts) {

    try {

        $test = Test-NetConnection `
            -ComputerName $DCIP `
            -Port $port `
            -WarningAction SilentlyContinue

        if ($test.TcpTestSucceeded) {

            Write-Success "TCP $port is reachable."

        }
        else {

            Write-Warn "TCP $port is NOT reachable."
        }

    }
    catch {

        Write-Warn "Could not test TCP $port."
    }
}

# ============================================================
# STEP 8 - ACTIVE DIRECTORY DNS + DC LOCATOR
# ============================================================

Write-Step "STEP 8 - Testing Active Directory DNS and DC discovery"

try {

    Clear-DnsClientCache -ErrorAction SilentlyContinue

    $srvName = "_ldap._tcp.dc._msdcs.$DomainName"

    $srvRecords = Resolve-DnsName `
        -Name $srvName `
        -Type SRV `
        -Server $DCIP `
        -ErrorAction Stop

    Write-Success "Active Directory LDAP SRV record resolves successfully."

    $srvRecords |
        Where-Object { $_.Type -eq "SRV" } |
        Select-Object NameTarget, Port, Priority, Weight |
        Format-Table -AutoSize

}
catch {

    Write-Fail "Active Directory DNS SRV lookup failed."
    Write-Host "Expected record: _ldap._tcp.dc._msdcs.$DomainName"
    Write-Host "DNS server     : $DCIP"
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Running Domain Controller Locator..." -ForegroundColor Yellow

$nltestOutput = & nltest.exe "/dsgetdc:$DomainName" 2>&1
$nltestExit = $LASTEXITCODE
$nltestOutput | Out-Host

if ($nltestExit -ne 0) {
    Write-Fail "Domain Controller Locator failed."
    Write-Host "The domain join will not be attempted until AD discovery works."
    exit 1
}

Write-Success "Domain Controller discovery succeeded."

# ============================================================
# STEP 9 - CHECK CURRENT DOMAIN STATUS
# ============================================================

Write-Step "STEP 9 - Checking current domain membership"

$script:DomainJoinPendingRestart = $false

$computerSystem = Get-CimInstance Win32_ComputerSystem

Write-Host "Computer Name : $($computerSystem.Name)"
Write-Host "Current Domain : $($computerSystem.Domain)"
Write-Host "Part Of Domain: $($computerSystem.PartOfDomain)"

# ============================================================
# STEP 10 - DOMAIN JOIN
# ============================================================

if (
    $computerSystem.PartOfDomain -and
    $computerSystem.Domain -ieq $DomainName
) {

    Write-Success "This machine is already joined to $DomainName."
    Write-Success "Skipping domain join."

}
else {

    Write-Step "STEP 10 - Joining the VulnCorp domain"

    Write-Host "Domain             : $DomainName"
    Write-Host "Domain Controller  : $DCIP"
    Write-Host "Domain Administrator: $DomainAdmin"
    Write-Host ""

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

        Write-Host "Attempting domain join..." -ForegroundColor Yellow

        Add-Computer `
            -DomainName $DomainName `
            -Credential $credential `
            -Force `
            -ErrorAction Stop

        Write-Success "Domain join request completed successfully."

        Write-Host ""
        Write-Warn "A restart is required to finalize domain membership."
        Write-Warn "The script will NOT restart here; it will first configure the remaining ASPER lab components."

        $script:DomainJoinPendingRestart = $true

    }
    catch {

        Write-Fail "DOMAIN JOIN FAILED."

        Write-Host ""
        Write-Host "Exact error:" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Red

        Write-Host ""
        Write-Host "Additional information:" -ForegroundColor Yellow
        Write-Host "Domain : $DomainName"
        Write-Host "DC     : $DCIP"
        Write-Host ""

        exit 1
    }
}

# ============================================================
# STEP 11 - SMBv1
# ============================================================

Write-Step "STEP 11 - Enabling SMBv1"

try {

    $smbFeature = Get-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol `
        -ErrorAction Stop

    Write-Host "Current SMB1 feature state: $($smbFeature.State)"

    if ($smbFeature.State -ne "Enabled") {

        Enable-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -All `
            -NoRestart `
            -ErrorAction Stop

        Write-Success "SMBv1 Windows feature enabled."

    }
    else {

        Write-Success "SMBv1 Windows feature already enabled."
    }

}
catch {

    Write-Warn "Could not configure SMBv1 Windows feature."
    Write-Warn $_.Exception.Message
}

try {

    Set-SmbServerConfiguration `
        -EnableSMB1Protocol $true `
        -Force `
        -ErrorAction Stop

    Write-Success "SMB server SMBv1 support enabled."

}
catch {

    Write-Warn "Could not enable SMBv1 server protocol."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 12 - SMB SIGNING
# ============================================================

Write-Step "STEP 12 - Disabling SMB signing requirement"

try {

    Set-SmbServerConfiguration `
        -RequireSecuritySignature $false `
        -Force `
        -ErrorAction Stop

    Write-Success "SMB signing requirement disabled."

}
catch {

    Write-Warn "Could not disable SMB signing."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 13 - PRINT SPOOLER
# ============================================================

Write-Step "STEP 13 - Configuring Print Spooler"

try {

    Set-Service `
        -Name Spooler `
        -StartupType Automatic `
        -ErrorAction Stop

    Start-Service `
        -Name Spooler `
        -ErrorAction SilentlyContinue

    Write-Success "Print Spooler is Automatic and Running."

}
catch {

    Write-Warn "Could not configure Print Spooler."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 14 - REMOTE DESKTOP
# ============================================================

Write-Step "STEP 14 - Enabling Remote Desktop"

try {

    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" `
        -Value 0 `
        -Type DWord `
        -Force

    Write-Success "Remote Desktop enabled."

}
catch {

    Write-Warn "Could not enable Remote Desktop."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 15 - DISABLE NLA
# ============================================================

Write-Step "STEP 15 - Disabling Network Level Authentication"

try {

    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -Name "UserAuthentication" `
        -Value 0 `
        -Type DWord `
        -Force

    Write-Success "Network Level Authentication disabled."

}
catch {

    Write-Warn "Could not disable NLA."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 16 - RDP FIREWALL
# ============================================================

Write-Step "STEP 16 - Enabling Remote Desktop firewall rules"

try {

    Enable-NetFirewallRule `
        -DisplayGroup "Remote Desktop" `
        -ErrorAction Stop

    Write-Success "Remote Desktop firewall rules enabled."

}
catch {

    Write-Warn "Could not enable RDP firewall rules."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 17 - LLMNR
# ============================================================

Write-Step "STEP 17 - Enabling LLMNR"

try {

    $llmnrPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"

    if (-not (Test-Path $llmnrPath)) {

        New-Item `
            -Path $llmnrPath `
            -Force | Out-Null
    }

    Set-ItemProperty `
        -Path $llmnrPath `
        -Name "EnableMulticast" `
        -Type DWord `
        -Value 1 `
        -Force

    Write-Success "LLMNR enabled."

}
catch {

    Write-Warn "Could not configure LLMNR."
}

# ============================================================
# STEP 18 - NETBIOS
# ============================================================

Write-Step "STEP 18 - Enabling NetBIOS over TCP/IP"

try {

    $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration |
        Where-Object {
            $_.IPEnabled -eq $true
        }

    foreach ($nic in $adapters) {

        Invoke-CimMethod `
            -InputObject $nic `
            -MethodName SetTcpipNetbios `
            -Arguments @{ TcpipNetbiosOptions = 1 } `
            -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Success "NetBIOS over TCP/IP configured."

}
catch {

    Write-Warn "Could not configure NetBIOS."
}

# ============================================================
# STEP 19 - WEAK LOCAL ADMIN
# ============================================================

Write-Step "STEP 19 - Creating vulnerable local administrator"

try {

    $localPassword = ConvertTo-SecureString `
        "Desktop@2024" `
        -AsPlainText `
        -Force

    $existingUser = Get-LocalUser `
        -Name "ws_admin" `
        -ErrorAction SilentlyContinue

    if (-not $existingUser) {

        New-LocalUser `
            -Name "ws_admin" `
            -Password $localPassword `
            -FullName "Workstation Administrator" `
            -Description "Intentional vulnerable lab account" `
            -PasswordNeverExpires `
            -UserMayNotChangePassword `
            -ErrorAction Stop | Out-Null

        Write-Success "Created local account ws_admin."

    }
    else {

        Set-LocalUser `
            -Name "ws_admin" `
            -Password $localPassword `
            -ErrorAction SilentlyContinue

        Write-Success "Local account ws_admin already exists."
    }

    Add-LocalGroupMember `
        -Group "Administrators" `
        -Member "ws_admin" `
        -ErrorAction SilentlyContinue

    Write-Success "ws_admin is a local Administrator."

}
catch {

    Write-Warn "Could not create/configure ws_admin."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 20 - UNQUOTED SERVICE PATH
# ============================================================

Write-Step "STEP 20 - Creating vulnerable service configuration"

try {

    $serviceRoot = "C:\Program Files\VulnCorp Service"

    New-Item `
        -ItemType Directory `
        -Path $serviceRoot `
        -Force | Out-Null

    $serviceExe = Join-Path $serviceRoot "service.exe"

    if (-not (Test-Path $serviceExe)) {

        Copy-Item `
            "$env:WINDIR\System32\notepad.exe" `
            $serviceExe `
            -Force
    }

    $existingService = Get-Service `
        -Name "VulnCorpSvc" `
        -ErrorAction SilentlyContinue

    if (-not $existingService) {

        New-Service `
            -Name "VulnCorpSvc" `
            -BinaryPathName $serviceExe `
            -DisplayName "VulnCorp Vulnerable Service" `
            -StartupType Manual `
            -ErrorAction Stop | Out-Null

        Write-Success "Vulnerable service created."

    }
    else {

        Write-Success "Vulnerable service already exists."
    }

}
catch {

    Write-Warn "Could not create vulnerable service."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 21 - ALWAYS INSTALL ELEVATED
# ============================================================

Write-Step "STEP 21 - Configuring AlwaysInstallElevated"

try {

    $machineInstallerPath =
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"

    $userInstallerPath =
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer"

    New-Item `
        -Path $machineInstallerPath `
        -Force | Out-Null

    New-Item `
        -Path $userInstallerPath `
        -Force | Out-Null

    Set-ItemProperty `
        -Path $machineInstallerPath `
        -Name AlwaysInstallElevated `
        -Type DWord `
        -Value 1 `
        -Force

    Set-ItemProperty `
        -Path $userInstallerPath `
        -Name AlwaysInstallElevated `
        -Type DWord `
        -Value 1 `
        -Force

    Write-Success "AlwaysInstallElevated configured."

}
catch {

    Write-Warn "Could not configure AlwaysInstallElevated."
}

# ============================================================
# STEP 22 - STORED CREDENTIALS
# ============================================================

Write-Step "STEP 22 - Planting vulnerable stored credentials"

try {

    cmdkey /add:fileserver.vulncorp.local `
           /user:VULNCORP\svc_backup `
           /pass:Backup@Svc2024 | Out-Null

    Write-Success "Stored credential planted."

}
catch {

    Write-Warn "Could not create stored credential."
}

# ============================================================
# STEP 23 - SMB PUBLIC SHARE
# ============================================================

Write-Step "STEP 23 - Creating vulnerable SMB share"

try {

    $sharePath = "C:\PublicShare"

    New-Item `
        -ItemType Directory `
        -Path $sharePath `
        -Force | Out-Null

    Set-Content `
        -Path "$sharePath\credentials.txt" `
        -Value @"
VulnCorp Lab Credential File

svc_backup : Backup@Svc2024
svc_erp    : Erp@Service99!
svc_sql    : Sql@Service77!
"@

    Set-Content `
        -Path "$sharePath\README.txt" `
        -Value "Intentional vulnerable SMB share for authorized ASPER lab testing."

    $existingShare = Get-SmbShare `
        -Name "Public" `
        -ErrorAction SilentlyContinue

    if (-not $existingShare) {

        New-SmbShare `
            -Name "Public" `
            -Path $sharePath `
            -ReadAccess "Everyone" `
            -FullAccess "Administrators" `
            -ErrorAction Stop | Out-Null

        Write-Success "SMB Public share created."

    }
    else {

        Write-Success "SMB Public share already exists."
    }

}
catch {

    Write-Warn "Could not create SMB Public share."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 24 - DISABLE WINDOWS FIREWALL
# ============================================================

Write-Step "STEP 24 - Disabling Windows Firewall for lab"

try {

    Set-NetFirewallProfile `
        -Profile Domain,Public,Private `
        -Enabled False `
        -ErrorAction Stop

    Write-Success "Windows Firewall disabled."

}
catch {

    Write-Warn "Could not disable Windows Firewall."
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 25 - DISABLE WINDOWS DEFENDER
# ============================================================

Write-Step "STEP 25 - Configuring Windows Defender for lab"

try {

    Set-MpPreference `
        -DisableRealtimeMonitoring $true `
        -ErrorAction SilentlyContinue

    Write-Success "Windows Defender real-time monitoring disabled."

}
catch {

    Write-Warn "Could not disable Defender real-time monitoring."
}

# ============================================================
# STEP 26 - FLAGS
# ============================================================

Write-Step "STEP 26 - Planting laboratory flags"

try {

    $flagPath = "C:\flags"

    New-Item `
        -ItemType Directory `
        -Path $flagPath `
        -Force | Out-Null

    Set-Content `
        -Path "$flagPath\FLAG-WORKSTATION.txt" `
        -Value "VULNCORP{INT-WS01-COMPROMISED}"

    Set-Content `
        -Path "$flagPath\FLAG-SMB.txt" `
        -Value "VULNCORP{SMBV1-ENABLED}"

    Set-Content `
        -Path "$flagPath\FLAG-RDP.txt" `
        -Value "VULNCORP{RDP-NLA-DISABLED}"

    Write-Success "Laboratory flags planted."

}
catch {

    Write-Warn "Could not plant all flags."
}

# ============================================================
# STEP 27 - FINAL VERIFICATION
# ============================================================

Write-Step "STEP 27 - Final deployment verification"

Write-Host ""
Write-Host "===== DOMAIN =====" -ForegroundColor White

$computerSystem = Get-CimInstance Win32_ComputerSystem

Write-Host "Computer Name : $($computerSystem.Name)"
Write-Host "Domain        : $($computerSystem.Domain)"
Write-Host "Part Of Domain: $($computerSystem.PartOfDomain)"

if ($script:DomainJoinPendingRestart) {
    Write-Warn "Domain join is pending restart. PartOfDomain becomes True after reboot."
}

Write-Host ""
Write-Host "===== SMB =====" -ForegroundColor White

try {

    $smbFeature = Get-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol

    $smbConfig = Get-SmbServerConfiguration

    Write-Host "SMB1 Feature          : $($smbFeature.State)"
    Write-Host "SMB1 Server Protocol  : $($smbConfig.EnableSMB1Protocol)"
    Write-Host "SMB Signing Required  : $($smbConfig.RequireSecuritySignature)"

}
catch {

    Write-Warn "Could not verify SMB configuration."
}

Write-Host ""
Write-Host "===== PRINT SPOOLER =====" -ForegroundColor White

try {

    $spooler = Get-Service -Name Spooler

    Write-Host "Status     : $($spooler.Status)"
    Write-Host "Start Type : $($spooler.StartType)"

}
catch {

    Write-Warn "Could not verify Print Spooler."
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

    Write-Warn "Could not verify RDP configuration."
}

Write-Host ""
Write-Host "===== IP / DNS =====" -ForegroundColor White

try {

    Get-NetIPAddress `
        -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*"
        } |
        Select-Object InterfaceAlias, IPAddress, PrefixLength |
        Format-Table -AutoSize

    Get-DnsClientServerAddress `
        -AddressFamily IPv4 |
        Select-Object InterfaceAlias, ServerAddresses |
        Format-Table -AutoSize

}
catch {

    Write-Warn "Could not display IP/DNS configuration."
}

# ============================================================
# COMPLETE
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "          DEPLOYMENT CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Configured components:" -ForegroundColor Cyan
Write-Host "  [+] Domain membership"
Write-Host "  [+] DHCP IP"
Write-Host "  [+] DC DNS"
Write-Host "  [+] SMBv1"
Write-Host "  [+] SMB signing disabled"
Write-Host "  [+] Print Spooler"
Write-Host "  [+] Remote Desktop"
Write-Host "  [+] NLA disabled"
Write-Host "  [+] RDP firewall rules"
Write-Host "  [+] LLMNR"
Write-Host "  [+] NetBIOS"
Write-Host "  [+] Vulnerable local account"
Write-Host "  [+] Vulnerable service configuration"
Write-Host "  [+] AlwaysInstallElevated"
Write-Host "  [+] Stored credentials"
Write-Host "  [+] SMB Public share"
Write-Host "  [+] Lab flags"
Write-Host ""

Write-Warn "This machine is intentionally vulnerable."
Write-Warn "Keep it isolated inside the authorized ASPER lab environment."

Write-Host ""
Write-Host "Deployment finished successfully." -ForegroundColor Green
Write-Host ""

Write-Host ""
Write-Warn "IMPORTANT: This script will NOT restart the VM automatically."
Write-Warn "Your Hyper-V VM previously booted Windows Setup from attached installation media."
Write-Warn "Complete the restart only when the VM owner/admin confirms it will boot from the installed system disk."
Write-Host ""
Write-Host "When a safe restart is available, restart Windows normally to finalize:"
Write-Host "  - Domain membership"
Write-Host "  - SMBv1 feature state (if Windows requires a reboot)"
Write-Host ""
Write-Success "All pre-reboot ASPER configuration steps are complete."

