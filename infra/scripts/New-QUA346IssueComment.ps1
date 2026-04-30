[CmdletBinding()]
param(
    [string]$ReadinessJsonPath = "C:\QM\repo\docs\ops\QUA-346_READINESS_CHECK_2026-04-28.json",
    [string]$OutMarkdownPath = "C:\QM\repo\docs\ops\QUA-346_ISSUE_COMMENT_2026-04-28.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReadinessJsonPath -PathType Leaf)) {
    throw "Readiness JSON not found: $ReadinessJsonPath"
}

$r = $null
$lastErr = $null
for ($i = 0; $i -lt 3; $i++) {
    try {
        $raw = Get-Content -LiteralPath $ReadinessJsonPath -Raw
        $r = $raw | ConvertFrom-Json -ErrorAction Stop
        break
    }
    catch {
        $lastErr = $_
        Start-Sleep -Milliseconds 150
    }
}
if (-not $r) {
    throw "Failed to parse readiness JSON after retries: $($lastErr.Exception.Message)"
}

$missing = @()
if ($r.PSObject.Properties.Name -contains 'manifest_missing_fields' -and $r.manifest_missing_fields) {
    $missing = @($r.manifest_missing_fields)
}

$lines = @()
$lines += "# QUA-346 Pipeline Update"
$lines += ""
$lines += "- checked_at: $($r.checked_at_local)"
$lines += "- ready: $($r.ready)"
$lines += "- unblock_owner: $($r.unblock_owner)"
$lines += ""
$lines += "## Readiness Checks"
foreach ($c in $r.checks) {
    $lines += ("- {0}: {1} ({2})" -f $c.name, $c.ok, $c.path)
}
$lines += ""
$lines += "## Missing Manifest Fields"
if ($missing.Count -eq 0) {
    $lines += "- none"
}
else {
    foreach ($m in $missing) {
        $lines += "- $m"
    }
}
$lines += ""
$lines += "## Card Candidates"
if ($r.card_candidates -and @($r.card_candidates).Count -gt 0) {
    foreach ($p in @($r.card_candidates)) {
        $lines += "- $p"
    }
}
else {
    $lines += "- none"
}
$lines += ""
$lines += "## Blocker / Unblock"
$missingChecks = @($r.checks | Where-Object { -not $_.ok } | ForEach-Object { $_.name })
if ($missingChecks.Count -eq 0 -and $missing.Count -eq 0) {
    $lines += "- blocker: none (ready for execution)."
}
else {
    $lines += "- blocker: unresolved checks/fields -> " + (($missingChecks + $missing) -join ", ")
}
$lines += "- unblock_action: $($r.unblock_action)"
$lines += ""
$lines += "## Next Operator Action"
$lines += "- $($r.next_action_when_ready)"

$content = ($lines -join "`r`n") + "`r`n"
Set-Content -LiteralPath $OutMarkdownPath -Value $content -Encoding UTF8

Write-Output ("status=ok out_markdown={0}" -f $OutMarkdownPath)
