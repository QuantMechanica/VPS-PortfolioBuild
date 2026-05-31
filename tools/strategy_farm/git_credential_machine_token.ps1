param(
    [string]$Operation = "get"
)

if ($Operation -ne "get") {
    exit 0
}

$request = @{}
while ($true) {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line -or $line -eq "") {
        break
    }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) {
        continue
    }
    $request[$line.Substring(0, $idx)] = $line.Substring($idx + 1)
}

$protocol = ""
if ($request.ContainsKey("protocol")) {
    $protocol = [string]$request["protocol"]
}
$hostName = ""
if ($request.ContainsKey("host")) {
    $hostName = [string]$request["host"]
}
if ($protocol -ne "https" -or $hostName -ne "github.com") {
    exit 0
}

$token = [Environment]::GetEnvironmentVariable("GH_TOKEN", "Machine")
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "Machine")
}
if ([string]::IsNullOrWhiteSpace($token)) {
    exit 0
}

Write-Output "username=x-access-token"
Write-Output "password=$token"
