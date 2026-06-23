#Requires -Version 5.1

[CmdletBinding()]

Param (
    [string]$SubjectName = $env:COMPUTERNAME,
    [int]$CertValidityDays = 3650,
    [switch]$SkipNetworkProfileCheck,
    [switch]$UnhardenedSettings,
    [switch]$Force
)

# Error handling
$ErrorActionPreference = "Stop"
trap { 
    Write-Error $_
    exit 1 
}

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: This script must be run as Administrator."
    exit 2
}

# Find and start the WinRM service.
$winrmService = Get-Service -Name WinRM
$null = $winrmService | Set-Service -StartupType Automatic -ErrorAction SilentlyContinue
$null = $winrmService | Start-Service -Name WinRM -ErrorAction SilentlyContinue


# WinRM should be running; check that we have a PS session config.
if ($SkipNetworkProfileCheck) {
    Enable-PSRemoting -SkipNetworkProfileCheck -Force
}
else {
    Enable-PSRemoting -Force
}

# Ensure LocalAccountTokenFilterPolicy is set to 1
$tokenPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$null = Set-ItemProperty -Path $tokenPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force

# Check if there is a SSL listener
$existingListener = Get-ChildItem WSMan:\localhost\Listener | Where-Object { $_.Keys -like "TRANSPORT=HTTPS" }
$existingThumbprint = $null
$needsNewCert = $false

if ($existingListener) {
    $wsmanListener = Get-WSManInstance -ResourceURI "winrm/config/Listener" -SelectorSet @{Transport = "HTTPS"; Address = "*" } -ErrorAction Stop
    $existingThumbprint = $wsmanListener.CertificateThumbprint
    
    if ($existingThumbprint) {
        # Check if certificate exists and is valid
        $existingCert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Thumbprint -eq $existingThumbprint }
        
        if ($existingCert) {
            $daysRemaining = ($existingCert.NotAfter - (Get-Date)).Days
            
            # Check if it's a legacy certificate (not using RSA or has old key length)
            $isLegacy = $false
            if ($existingCert.PublicKey.Key.KeySize -lt 2048) {
                $isLegacy = $true
            }
            
            # Check if it's about to expire (less than 365 days / 1 year)
            $isExpiring = $daysRemaining -lt 360
            
            if ($isLegacy -or $isExpiring -or $Force) {
                $needsNewCert = $true
            }
        }
        else {
            $needsNewCert = $true
        }
    }
    else {
        $needsNewCert = $true
    }
}
else {
    $needsNewCert = $true
}

# Generate new certificate if needed
if ($needsNewCert) {
    # Remove old HTTPS listener
    if ($existingListener) {
        $null = Remove-WSManInstance -ResourceURI "winrm/config/Listener" -SelectorSet @{Transport = "HTTPS"; Address = "*" }
    }
    
    # Remove old/legacy certificates if requested
    if ($existingThumbprint) {
        $null = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Thumbprint -eq $existingThumbprint } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    
    # Check for existing cert with same SubjectName and remove if Force
    if ($Force) {
        $oldCerts = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=$SubjectName*" }
        if ($oldCerts) {
            $null = $oldCerts | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Generate new certificate
    $cert = New-SelfSignedCertificate -Type SSLServerAuthentication `
        -Subject "CN=$SubjectName" `
        -DnsName $SubjectName, $env:COMPUTERNAME, "$env:COMPUTERNAME.$env:USERDNSDOMAIN" `
        -KeyAlgorithm RSA `
        -KeyLength 4096 `
        -KeyUsage DigitalSignature, KeyEncipherment `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -NotAfter (Get-Date).AddDays($CertValidityDays)

    # this does not seem to work - bug?
    #$null = New-WSManInstance -ResourceURI "http://schemas.microsoft.com/wbem/wsman/1/config/listener" -SelectorSet $selectorSet -ValueSet $valueSet

    $null = New-Item -Path "WSMan:\localhost\Listener" -Address "*" -Transport "HTTPS" -HostName $SubjectName -CertificateThumbprint $cert.Thumbprint -Force
}

if ($UnhardenedSettings) {
    ### this is mainly for troubleshooting

    # enable basic auth
    $null = Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $true

    # disable credssp
    $null = Disable-WSManCredSSP -role Server -ErrorAction SilentlyContinue
}
else {
    # hardened settings    

    # disable basic auth
    $null = Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $false

    # enable credssp
    $null = Enable-WSManCredSSP -role server -Force -ErrorAction SilentlyContinue
}

$winRmInfo = @(
    [pscustomobject]@{
        Port     = 5985
        Protocol = "HTTP"
    }
    [pscustomobject]@{
        Port     = 5986
        Protocol = "HTTPS"
    }
)

foreach ($item in $winRmInfo) {
    $ruleName = "Windows Remote Management ({0}-In)" -f $item.Protocol
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        $null = New-NetFirewallRule -DisplayName $ruleName `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $item.Port `
            -Action Allow `
            -Profile Any
    }
}

# test connection
$httpResult = Invoke-Command -ComputerName "localhost" -ScriptBlock { $using:env:COMPUTERNAME } -ErrorVariable httpError -ErrorAction SilentlyContinue

$httpsOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$httpsResult = New-PSSession -UseSSL -ComputerName "localhost" -SessionOption $httpsOptions -ErrorVariable httpsError -ErrorAction SilentlyContinue

If ($httpResult -and $httpsResult) {
    "[TEST] HTTP: Enabled | HTTPS: Enabled"
}
ElseIf ($httpsResult -and !$httpResult) {
    "[TEST] HTTP: Disabled | HTTPS: Enabled"
}
ElseIf ($httpResult -and !$httpsResult) {
    "[TEST] HTTP: Enabled | HTTPS: Disabled"
}
Else {
    "[TEST] HTTP: Disabled | HTTPS: Disabled"
    Throw "Unable to establish an HTTP or HTTPS remoting session."
}

$null = Remove-PSSession $httpsResult
