[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$InfraAuditPath = 'infra\reports\infra_audit_latest.json',
    [string]$OutPath = 'docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$auditFull = Join-Path $RepoRoot $InfraAuditPath
$outFull = Join-Path $RepoRoot $OutPath

if (-not (Test-Path -LiteralPath $auditFull)) {
    throw "Infra audit report missing: $auditFull"
}

$audit = Get-Content -Raw -LiteralPath $auditFull | ConvertFrom-Json
$allChecks = @($audit.checks)
$qua95Checks = @($allChecks | Where-Object { $_.name -like 'qua95_*' })
$nonQua95Issues = @(@($audit.issues) | Where-Object { $_.name -notlike 'qua95_*' })
$qua95Issues = @(@($audit.issues) | Where-Object { $_.name -like 'qua95_*' })

$summary = [ordered]@{
    issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    infra_audit_overall_status = $audit.overall_status
    infra_audit_checks_count = @($allChecks).Count
    infra_audit_issues_count = @($audit.issues).Count
    qua95_checks_count = @($qua95Checks).Count
    qua95_issues_count = @($qua95Issues).Count
    non_qua95_issues_count = @($nonQua95Issues).Count
    qua95_checks = @($qua95Checks | Select-Object name, status)
    non_qua95_issue_names = @($nonQua95Issues | ForEach-Object { $_.name })
}

$outDir = Split-Path -Parent $outFull
if ($outDir) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Output ("wrote={0}" -f $outFull)
Write-Output ("qua95_issues_count={0}" -f $summary.qua95_issues_count)
Write-Output ("non_qua95_issues_count={0}" -f $summary.non_qua95_issues_count)
exit 0
