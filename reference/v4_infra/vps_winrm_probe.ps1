[CmdletBinding()]
param(
    [string[]]$ComputerNames = @("ftmo-hyonix", "vps-hyonix.taild20dab.ts.net", "100.107.63.109"),
    [pscredential]$Credential
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Try-Resolve {
    param([string]$Target)
    try {
        [System.Net.Dns]::GetHostAddresses($Target) |
            ForEach-Object { $_.IPAddressToString } |
            Select-Object -Unique
    }
    catch {
        @()
    }
}

function Try-Port {
    param(
        [string]$Target,
        [int]$Port
    )
    $parsedIp = $null
    $isIp = [System.Net.IPAddress]::TryParse($Target, [ref]$parsedIp)
    if (-not $isIp) {
        $resolved = @(Try-Resolve -Target $Target)
        if ($resolved.Count -eq 0) {
            return [pscustomobject]@{
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
                port = $Port
                tcp_ok = $false
                error = "timeout"
            }
        }
        $client.EndConnect($connect)
        $client.Close()
        [pscustomobject]@{
            port = $Port
            tcp_ok = $true
        }
    }
    catch {
        [pscustomobject]@{
            port = $Port
            tcp_ok = $false
            error = $_.Exception.Message
        }
    }
}

function Try-Wsman {
    param([string]$Target)

    $parsedIp = $null
    $isIp = [System.Net.IPAddress]::TryParse($Target, [ref]$parsedIp)
    if (-not $isIp) {
        $resolved = @(Try-Resolve -Target $Target)
        if ($resolved.Count -eq 0) {
            return [pscustomobject]@{
                ok = $false
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
        [pscustomobject]@{
            ok = $true
            http_status = $status
        }
    }
    catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -ne $response) {
            $status = [int]([System.Net.HttpWebResponse]$response).StatusCode
            [pscustomobject]@{
                ok = $true
                http_status = $status
            }
        }
        else {
            [pscustomobject]@{
                ok = $false
                error = $_.Exception.Message
            }
        }
    }
    catch {
        [pscustomobject]@{
            ok = $false
            error = $_.Exception.Message
        }
    }
}

function Try-InvokeProbe {
    param(
        [string]$Target,
        [pscredential]$ProbeCredential
    )

    $parsedIp = $null
    $isIp = [System.Net.IPAddress]::TryParse($Target, [ref]$parsedIp)
    if (-not $isIp) {
        $resolved = @(Try-Resolve -Target $Target)
        if ($resolved.Count -eq 0) {
            return [pscustomobject]@{
                ok = $false
                error = "name not resolved"
            }
        }
    }

    $scriptBlock = {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average

        $terminal = Get-Process -Name terminal64 -ErrorAction SilentlyContinue
        $tester = Get-Process -Name metatester64 -ErrorAction SilentlyContinue
        $python = Get-Process -Name python -ErrorAction SilentlyContinue

        [pscustomobject]@{
            timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            computer = $env:COMPUTERNAME
            disks = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
                Select-Object DeviceID, FreeSpace, Size)
            memory_total_bytes = [int64]$os.TotalVisibleMemorySize * 1024
            memory_free_bytes = [int64]$os.FreePhysicalMemory * 1024
            cpu_avg_load_pct = [int]$cpu.Average
            process_counts = [ordered]@{
                terminal64 = @($terminal).Count
                metatester64 = @($tester).Count
                python = @($python).Count
            }
            process_pids = [ordered]@{
                terminal64 = @($terminal | Select-Object -ExpandProperty Id)
                metatester64 = @($tester | Select-Object -ExpandProperty Id)
                python = @($python | Select-Object -ExpandProperty Id)
            }
        }
    }

    $params = @{
        ComputerName = $Target
        ScriptBlock = $scriptBlock
        ErrorAction = "Stop"
    }
    if ($ProbeCredential) {
        $params.Credential = $ProbeCredential
    }

    try {
        [pscustomobject]@{
            ok = $true
            data = (Invoke-Command @params)
        }
    }
    catch {
        [pscustomobject]@{
            ok = $false
            error = $_.Exception.Message
        }
    }
}

$probes = foreach ($target in $ComputerNames) {
    [pscustomobject]@{
        target = $target
        resolved_ips = @(Try-Resolve -Target $target)
        tcp_5985 = Try-Port -Target $target -Port 5985
        tcp_5986 = Try-Port -Target $target -Port 5986
        wsman = Try-Wsman -Target $target
        invoke = Try-InvokeProbe -Target $target -ProbeCredential $Credential
    }
}

$firstSuccess = $probes | Where-Object { $_.invoke.ok } | Select-Object -First 1

[pscustomobject]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    probe_targets = $ComputerNames
    first_invoke_success_target = if ($firstSuccess) { $firstSuccess.target } else { $null }
    probes = $probes
} | ConvertTo-Json -Depth 10
