[CmdletBinding()]
param(
    [string]$HostAlias = "ftmo-hyonix",
    [string]$HostFqdn = "vps-hyonix.taild20dab.ts.net",
    [string]$HostIp = "100.107.63.109",
    [switch]$ApplyHostsFile,
    [switch]$ApplyTrustedHosts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-Host {
    param([string]$Name)
    try {
        [System.Net.Dns]::GetHostAddresses($Name) |
            ForEach-Object { $_.IPAddressToString } |
            Select-Object -Unique
    }
    catch {
        @()
    }
}

function Test-Port {
    param(
        [string]$Target,
        [int]$Port
    )
    $parsedIp = $null
    $isIp = [System.Net.IPAddress]::TryParse($Target, [ref]$parsedIp)
    if (-not $isIp) {
        $resolved = @(Resolve-Host -Name $Target)
        if ($resolved.Count -eq 0) {
            return [pscustomobject]@{
                target = $Target
                port = $Port
                tcp_ok = $false
                error = "name not resolved"
            }
        }
    }

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $connect = $client.BeginConnect($Target, $Port, $null, $null)
        $connected = $connect.AsyncWaitHandle.WaitOne(2000, $false)
        if (-not $connected) {
            $client.Close()
            return [pscustomobject]@{
                target = $Target
                port = $Port
                tcp_ok = $false
                error = "timeout"
            }
        }
        $client.EndConnect($connect)
        $client.Close()
        return [pscustomobject]@{
            target = $Target
            port = $Port
            tcp_ok = $true
        }
    }
    catch {
        return [pscustomobject]@{
            target = $Target
            port = $Port
            tcp_ok = $false
            error = $_.Exception.Message
        }
    }
}

function Test-Wsman {
    param([string]$Target)

    $parsedIp = $null
    $isIp = [System.Net.IPAddress]::TryParse($Target, [ref]$parsedIp)
    if (-not $isIp) {
        $resolved = @(Resolve-Host -Name $Target)
        if ($resolved.Count -eq 0) {
            return [pscustomobject]@{
                target = $Target
                wsman_ok = $false
                error = "name not resolved"
            }
        }
    }

    $uri = "http://$Target`:5985/wsman"
    try {
        $req = [System.Net.HttpWebRequest]::Create($uri)
        $req.Method = "GET"
        $req.Timeout = 3000
        $req.ReadWriteTimeout = 3000
        $resp = [System.Net.HttpWebResponse]$req.GetResponse()
        $status = [int]$resp.StatusCode
        $resp.Close()
        return [pscustomobject]@{
            target = $Target
            wsman_ok = $true
            http_status = $status
        }
    }
    catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -ne $response) {
            $status = [int]([System.Net.HttpWebResponse]$response).StatusCode
            return [pscustomobject]@{
                target = $Target
                wsman_ok = $true
                http_status = $status
            }
        }
        return [pscustomobject]@{
            target = $Target
            wsman_ok = $false
            error = $_.Exception.Message
        }
    }
    catch {
        return [pscustomobject]@{
            target = $Target
            wsman_ok = $false
            error = $_.Exception.Message
        }
    }
}

function Add-HostsLine {
    param(
        [string]$HostsFile,
        [string]$Ip,
        [string]$Alias,
        [string]$Fqdn
    )

    $line = "$Ip`t$Alias`t$Fqdn"
    $existing = Get-Content -LiteralPath $HostsFile -ErrorAction Stop
    $hasAlias = $existing | Where-Object { $_ -match "(^|\s)$([regex]::Escape($Alias))($|\s)" }
    $hasFqdn = $existing | Where-Object { $_ -match "(^|\s)$([regex]::Escape($Fqdn))($|\s)" }

    if ($hasAlias -or $hasFqdn) {
        return [pscustomobject]@{
            changed = $false
            note = "hosts entry already present"
            line = $line
        }
    }

    Add-Content -LiteralPath $HostsFile -Value $line -ErrorAction Stop
    return [pscustomobject]@{
        changed = $true
        note = "hosts entry added"
        line = $line
    }
}

function Merge-TrustedHosts {
    param([string[]]$Entries)

    $current = ""
    try {
        $current = (Get-Item -Path WSMan:\localhost\Client\TrustedHosts -ErrorAction Stop).Value
    }
    catch {
        $current = ""
    }

    $merged = @()
    if ($current) {
        $merged += ($current -split ",")
    }
    $merged += $Entries
    $merged = $merged |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique

    $newValue = $merged -join ","
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $newValue -Force -ErrorAction Stop

    [pscustomobject]@{
        changed = ($newValue -ne $current)
        previous = $current
        current = $newValue
    }
}

$isAdmin = Test-IsAdmin
$summary = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    is_admin = $isAdmin
    host_alias = $HostAlias
    host_fqdn = $HostFqdn
    host_ip = $HostIp
    apply_hosts_file = [bool]$ApplyHostsFile
    apply_trusted_hosts = [bool]$ApplyTrustedHosts
    hosts_file_update = $null
    trusted_hosts_update = $null
    resolution = [ordered]@{
        alias = @(Resolve-Host -Name $HostAlias)
        fqdn = @(Resolve-Host -Name $HostFqdn)
        ip = @($HostIp)
    }
    connectivity = [ordered]@{
        tcp_5985 = @(
            Test-Port -Target $HostAlias -Port 5985
            Test-Port -Target $HostFqdn -Port 5985
            Test-Port -Target $HostIp -Port 5985
        )
        wsman = @(
            Test-Wsman -Target $HostAlias
            Test-Wsman -Target $HostFqdn
            Test-Wsman -Target $HostIp
        )
    }
}

if (($ApplyHostsFile -or $ApplyTrustedHosts) -and -not $isAdmin) {
    throw "Apply modes require an elevated PowerShell session (Run as Administrator)."
}

if ($ApplyHostsFile) {
    $hostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
    $summary.hosts_file_update = Add-HostsLine -HostsFile $hostsFile -Ip $HostIp -Alias $HostAlias -Fqdn $HostFqdn
}

if ($ApplyTrustedHosts) {
    $summary.trusted_hosts_update = Merge-TrustedHosts -Entries @($HostAlias, $HostFqdn, $HostIp)
}

$summary | ConvertTo-Json -Depth 8
