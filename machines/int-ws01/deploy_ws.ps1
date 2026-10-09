#Requires -RunAsAdministrator

<#
VulnCorp - int-ws01
Windows Server 2019 Domain-Joined Lab Member Server

Domain : vulncorp.local
DC/DNS : 192.168.80.32

IMPORTANT:
- This machine remains a MEMBER SERVER.
- It is NOT promoted to a Domain Controller.
- IPv4 remains DHCP.
- DNS is pointed to the VulnCorp Domain Controller.
- First run joins the domain and reboots.
- Run the script again after reboot to finish configuration.
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
# HELPER FUNCTIONS
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

    $principal = New-Object `
        Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-PrimaryAdapter {

    return Get-NetAdapter |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.HardwareInterface -eq $true
        } |
        Sort-Object ifIndex |
        Select-Object -First 1
}

# ============================================================
# START
# ============================================================

Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "          VULNCORP - int-ws01 DEPLOYMENT" -ForegroundColor Cyan
Write-Host "       Windows Server 2019 Member Server" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""

# ============================================================
# STEP 1 - ADMINISTRATOR
# ============================================================

Write-Step "STEP 1 - Checking Administrator privileges"

if (-not (Test-Administrator)) {

    Write-Fail "PowerShell must be run as Administrator."
    exit 1
}

Write-Success "PowerShell is running as Administrator."

# ============================================================
# STEP 2 - OPERATING SYSTEM
# ============================================================

Write-Step "STEP 2 - Checking Windows version"

$os = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System : $($os.Caption)"
Write-Host "Version          : $($os.Version)"
Write-Host "Build            : $($os.BuildNumber)"

if ($os.Caption -notmatch "Windows Server 2019") {

    Write-Warn "This script was designed for Windows Server 2019."

    $answer = Read-Host "Continue anyway? (Y/N)"

    if ($answer -notmatch "^[Yy]$") {
        exit 1
    }
}

Write-Success "Operating system check completed."

# ============================================================
# STEP 3 - NETWORK ADAPTER
# ============================================================

Write-Step "STEP 3 - Detecting network adapter"

$adapter = Get-PrimaryAdapter

if (-not $adapter) {

    Write-Fail "No active Ethernet adapter was found."
    exit 1
}

Write-Host "Adapter : $($adapter.Name)"
Write-Host "Index   : $($adapter.ifIndex)"
Write-Host "Status  : $($adapter.Status)"

Write-Success "Network adapter detected."

# ============================================================
# STEP 4 - DHCP + DOMAIN DNS
# ============================================================

Write-Step "STEP 4 - Configuring network"

Write-Host "IP configuration : DHCP"
Write-Host "DNS Server       : $DCIP"

try {

    Set-NetIPInterface `
        -InterfaceIndex $adapter.ifIndex `
        -AddressFamily IPv4 `
        -Dhcp Enabled `
        -ErrorAction SilentlyContinue

    Set-DnsClientServerAddress `
        -InterfaceIndex $adapter.ifIndex `
        -ServerAddresses $DCIP `
        -ErrorAction Stop

    Clear-DnsClientCache -ErrorAction SilentlyContinue

    Write-Success "DNS configured to $DCIP."
    Write-Success "IPv4 remains DHCP."

}
catch {

    Write-Fail "Network/DNS configuration failed."
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ============================================================
# STEP 5 - SHOW CURRENT NETWORK
# ============================================================

Write-Step "STEP 5 - Current network configuration"

Get-NetIPAddress `
    -InterfaceIndex $adapter.ifIndex `
    -AddressFamily IPv4 `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "169.254.*"
    } |
    Select-Object IPAddress,PrefixLength |
    Format-Table -AutoSize

Write-Host "DNS:"

Get-DnsClientServerAddress `
    -InterfaceIndex $adapter.ifIndex `
    -AddressFamily IPv4 |
    Select-Object -ExpandProperty ServerAddresses

# ============================================================
# STEP 6 - VERIFY DOMAIN DNS
# ============================================================

Write-Step "STEP 6 - Checking domain DNS"

try {

    $result = Resolve-DnsName `
        -Name $DomainName `
        -ErrorAction Stop

    Write-Success "$DomainName resolves successfully."

    $result |
        Where-Object {
            $_.Type -eq "A"
        } |
        Select-Object Name,IPAddress |
        Format-Table -AutoSize

}
catch {

    Write-Fail "$DomainName cannot be resolved."

    Write-Host ""
    Write-Host "Expected DNS server: $DCIP"
    Write-Host ""

    exit 1
}

# ============================================================
# STEP 7 - VERIFY AD DOMAIN CONTROLLER DISCOVERY
# ============================================================

Write-Step "STEP 7 - Discovering VulnCorp Domain Controller"

$nltestOutput = & nltest.exe "/dsgetdc:$DomainName" 2>&1

$nltestOutput | Out-Host

if ($LASTEXITCODE -ne 0) {

    Write-Fail "Active Directory Domain Controller discovery failed."

    Write-Host ""
    Write-Host "Verify that:"
    Write-Host "  1. The DC is running."
    Write-Host "  2. DNS points to $DCIP."
    Write-Host "  3. DNS, NTDS and Netlogon are running on the DC."
    Write-Host ""

    exit 1
}

Write-Success "Domain Controller discovery succeeded."

# ============================================================
# STEP 8 - CHECK DOMAIN MEMBERSHIP
# ============================================================

Write-Step "STEP 8 - Checking domain membership"

$computerSystem = Get-CimInstance Win32_ComputerSystem

Write-Host "Computer Name  : $($computerSystem.Name)"
Write-Host "Current Domain : $($computerSystem.Domain)"
Write-Host "Part Of Domain : $($computerSystem.PartOfDomain)"

# ============================================================
# STEP 9 - DOMAIN JOIN
# ============================================================

if (
    -not $computerSystem.PartOfDomain -or
    $computerSystem.Domain -ine $DomainName
) {

    Write-Step "STEP 9 - Joining VulnCorp domain"

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

        Write-Host "Domain : $DomainName"
        Write-Host "Account: $DomainAdmin"
        Write-Host ""
        Write-Host "Joining domain..." -ForegroundColor Yellow

        # IMPORTANT:
        # Do NOT specify -Server here.
        # AD DNS / DC Locator chooses the Domain Controller.
        Add-Computer `
            -DomainName $DomainName `
            -Credential $credential `
            -Force `
            -ErrorAction Stop

        Write-Success "DOMAIN JOIN SUCCESSFUL."

        Write-Host ""
        Write-Host "The computer will restart to complete domain membership." `
            -ForegroundColor Yellow

        Start-Sleep -Seconds 5

        Restart-Computer -Force
        exit

    }
    catch {

        Write-Fail "DOMAIN JOIN FAILED."

        Write-Host ""
        Write-Host "Exact error:" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        exit 1
    }
}

Write-Success "Machine is already joined to $DomainName."
Write-Success "Continuing with member-server configuration."

# ============================================================
# STEP 10 - SMBv1
# ============================================================

Write-Step "STEP 10 - Configuring SMBv1"

try {

    $feature = Get-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol

    if ($feature.State -ne "Enabled") {

        Enable-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -All `
            -NoRestart `
            -ErrorAction Stop | Out-Null
    }

    Set-SmbServerConfiguration `
        -EnableSMB1Protocol $true `
        -Force `
        -ErrorAction Stop

    Write-Success "SMBv1 enabled."

}
catch {

    Write-Warn "SMBv1 configuration encountered an error:"
    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 11 - SMB SIGNING
# ============================================================

Write-Step "STEP 11 - Configuring SMB signing"

try {

    Set-SmbServerConfiguration `
        -RequireSecuritySignature $false `
        -Force `
        -ErrorAction Stop

    Write-Success "SMB signing requirement disabled."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 12 - PRINT SPOOLER
# ============================================================

Write-Step "STEP 12 - Configuring Print Spooler"

try {

    Set-Service `
        -Name Spooler `
        -StartupType Automatic

    Start-Service `
        -Name Spooler `
        -ErrorAction SilentlyContinue

    Write-Success "Print Spooler enabled and running."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 13 - REMOTE DESKTOP
# ============================================================

Write-Step "STEP 13 - Configuring Remote Desktop"

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

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 14 - NLA
# ============================================================

Write-Step "STEP 14 - Configuring Network Level Authentication"

try {

    Set-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -Name "UserAuthentication" `
        -Value 0 `
        -Type DWord `
        -Force

    Write-Success "NLA disabled."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 15 - RDP FIREWALL RULES
# ============================================================

Write-Step "STEP 15 - Configuring RDP firewall rules"

try {

    Enable-NetFirewallRule `
        -DisplayGroup "Remote Desktop" `
        -ErrorAction Stop

    Write-Success "Remote Desktop firewall rules enabled."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 16 - LLMNR
# ============================================================

Write-Step "STEP 16 - Configuring LLMNR"

try {

    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"

    if (-not (Test-Path $path)) {

        New-Item `
            -Path $path `
            -Force | Out-Null
    }

    Set-ItemProperty `
        -Path $path `
        -Name EnableMulticast `
        -Type DWord `
        -Value 1 `
        -Force

    Write-Success "LLMNR enabled."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 17 - NETBIOS
# ============================================================

Write-Step "STEP 17 - Configuring NetBIOS"

try {

    $networkConfigs =
        Get-CimInstance Win32_NetworkAdapterConfiguration |
        Where-Object {
            $_.IPEnabled -eq $true
        }

    foreach ($nic in $networkConfigs) {

        Invoke-CimMethod `
            -InputObject $nic `
            -MethodName SetTcpipNetbios `
            -Arguments @{
                TcpipNetbiosOptions = 1
            } `
            -ErrorAction SilentlyContinue |
            Out-Null
    }

    Write-Success "NetBIOS over TCP/IP enabled."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 18 - LAB LOCAL ADMIN
# ============================================================

Write-Step "STEP 18 - Configuring lab local administrator"

try {

    $localPassword = ConvertTo-SecureString `
        "Desktop@2024" `
        -AsPlainText `
        -Force

    $user = Get-LocalUser `
        -Name "ws_admin" `
        -ErrorAction SilentlyContinue

    if (-not $user) {

        New-LocalUser `
            -Name "ws_admin" `
            -Password $localPassword `
            -FullName "Workstation Administrator" `
            -Description "ASPER lab account" `
            -PasswordNeverExpires `
            -ErrorAction Stop |
            Out-Null

        Write-Success "ws_admin created."
    }
    else {

        Set-LocalUser `
            -Name "ws_admin" `
            -Password $localPassword `
            -ErrorAction SilentlyContinue

        Write-Success "ws_admin already exists."
    }

    Add-LocalGroupMember `
        -Group "Administrators" `
        -Member "ws_admin" `
        -ErrorAction SilentlyContinue

    Write-Success "ws_admin configured as local Administrator."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 19 - LAB SERVICE
# ============================================================

Write-Step "STEP 19 - Configuring lab service"

try {

    $serviceRoot = "C:\Program Files\VulnCorp Service"

    New-Item `
        -ItemType Directory `
        -Path $serviceRoot `
        -Force |
        Out-Null

    $serviceExe = Join-Path `
        $serviceRoot `
        "service.exe"

    if (-not (Test-Path $serviceExe)) {

        Copy-Item `
            "$env:WINDIR\System32\notepad.exe" `
            $serviceExe `
            -Force
    }

    $service = Get-Service `
        -Name "VulnCorpSvc" `
        -ErrorAction SilentlyContinue

    if (-not $service) {

        New-Service `
            -Name "VulnCorpSvc" `
            -BinaryPathName $serviceExe `
            -DisplayName "VulnCorp Lab Service" `
            -StartupType Manual `
            -ErrorAction Stop |
            Out-Null

        Write-Success "VulnCorpSvc created."
    }
    else {

        Write-Success "VulnCorpSvc already exists."
    }

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 20 - ALWAYS INSTALL ELEVATED
# ============================================================

Write-Step "STEP 20 - Configuring AlwaysInstallElevated"

try {

    $machinePath =
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"

    $userPath =
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer"

    New-Item `
        -Path $machinePath `
        -Force |
        Out-Null

    New-Item `
        -Path $userPath `
        -Force |
        Out-Null

    Set-ItemProperty `
        -Path $machinePath `
        -Name AlwaysInstallElevated `
        -Type DWord `
        -Value 1 `
        -Force

    Set-ItemProperty `
        -Path $userPath `
        -Name AlwaysInstallElevated `
        -Type DWord `
        -Value 1 `
        -Force

    Write-Success "AlwaysInstallElevated configured."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 21 - LAB STORED CREDENTIAL
# ============================================================

Write-Step "STEP 21 - Creating lab stored credential"

try {

    cmdkey `
        /add:fileserver.vulncorp.local `
        /user:VULNCORP\svc_backup `
        /pass:Backup@Svc2024 |
        Out-Null

    Write-Success "Lab credential stored."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 22 - LAB SMB SHARE
# ============================================================

Write-Step "STEP 22 - Creating lab SMB share"

try {

    $sharePath = "C:\PublicShare"

    New-Item `
        -ItemType Directory `
        -Path $sharePath `
        -Force |
        Out-Null

    Set-Content `
        -Path "$sharePath\credentials.txt" `
        -Value @"
VulnCorp ASPER Lab Credential File

svc_backup : Backup@Svc2024
svc_erp    : Erp@Service99!
svc_sql    : Sql@Service77!
"@

    Set-Content `
        -Path "$sharePath\README.txt" `
        -Value "ASPER isolated cybersecurity laboratory share."

    $share = Get-SmbShare `
        -Name "Public" `
        -ErrorAction SilentlyContinue

    if (-not $share) {

        New-SmbShare `
            -Name "Public" `
            -Path $sharePath `
            -ReadAccess "Everyone" `
            -FullAccess "Administrators" `
            -ErrorAction Stop |
            Out-Null
    }

    Write-Success "Public SMB share configured."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 23 - LAB FLAGS
# ============================================================

Write-Step "STEP 23 - Creating lab flags"

try {

    $flagPath = "C:\flags"

    New-Item `
        -ItemType Directory `
        -Path $flagPath `
        -Force |
        Out-Null

    Set-Content `
        "$flagPath\FLAG-WORKSTATION.txt" `
        "VULNCORP{INT-WS01-COMPROMISED}"

    Set-Content `
        "$flagPath\FLAG-SMB.txt" `
        "VULNCORP{SMBV1-ENABLED}"

    Set-Content `
        "$flagPath\FLAG-RDP.txt" `
        "VULNCORP{RDP-NLA-DISABLED}"

    Write-Success "Lab flags created."

}
catch {

    Write-Warn $_.Exception.Message
}

# ============================================================
# STEP 24 - FINAL VERIFICATION
# ============================================================

Write-Step "STEP 24 - Final verification"

$computerSystem = Get-CimInstance Win32_ComputerSystem

Write-Host ""
Write-Host "DOMAIN" -ForegroundColor White
Write-Host "------"
Write-Host "Computer : $($computerSystem.Name)"
Write-Host "Domain   : $($computerSystem.Domain)"
Write-Host "Joined   : $($computerSystem.PartOfDomain)"

Write-Host ""
Write-Host "SMB" -ForegroundColor White
Write-Host "---"

try {

    $smb = Get-SmbServerConfiguration

    Write-Host "SMBv1 Enabled     : $($smb.EnableSMB1Protocol)"
    Write-Host "Signing Required  : $($smb.RequireSecuritySignature)"

}
catch {

    Write-Warn "SMB verification failed."
}

Write-Host ""
Write-Host "PRINT SPOOLER" -ForegroundColor White
Write-Host "-------------"

try {

    Get-Service Spooler |
        Select-Object Status,StartType |
        Format-Table -AutoSize

}
catch {

    Write-Warn "Spooler verification failed."
}

Write-Host ""
Write-Host "REMOTE DESKTOP" -ForegroundColor White
Write-Host "--------------"

try {

    $rdp = Get-ItemProperty `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"

    $nla = Get-ItemProperty `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

    Write-Host "fDenyTSConnections : $($rdp.fDenyTSConnections)"
    Write-Host "UserAuthentication : $($nla.UserAuthentication)"

}
catch {

    Write-Warn "RDP verification failed."
}

# ============================================================
# FINISHED
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "             DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Success "Domain       : $($computerSystem.Domain)"
Write-Success "Domain joined: $($computerSystem.PartOfDomain)"

Write-Host ""
Write-Warn "This server is intentionally configured for the isolated ASPER lab."
Write-Host ""

$restart = Read-Host "Restart now to apply all changes? (Y/N)"

if ($restart -match "^[Yy]$") {

    Restart-Computer -Force
}
else {

    Write-Warn "Restart skipped. Restart the server before testing the lab."
}