[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$AuditSignalPath = 'docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$full = Join-Path $RepoRoot $AuditSignalPath
if (-not (Test-Path -LiteralPath $full)) {
    Write-Host ("status=critical reason=missing path={0}" -f $full)
    exit 1
}

$s = Get-Content -Raw -LiteralPath $full | ConvertFrom-Json
$issues = @()

if ($s.issue -ne 'QUA-95') { $issues += ("issue_mismatch={0}" -f $s.issue) }
if ([int]$s.infra_audit_checks_count -lt 1) { $issues += 'checks_count_invalid' }
if ([int]$s.infra_audit_issues_count -lt 0) { $issues += 'issues_count_invalid' }
if ([int]$s.qua95_checks_count -lt 1) { $issues += 'qua95_checks_count_invalid' }
if ([int]$s.qua95_issues_count -lt 0) { $issues += 'qua95_issues_count_invalid' }
if ([int]$s.non_qua95_issues_count -lt 0) { $issues += 'non_qua95_issues_count_invalid' }
if ($null -eq $s.qua95_checks) { $issues += 'qua95_checks_missing' }
if (@($s.qua95_checks).Count -ne [int]$s.qua95_checks_count) { $issues += 'qua95_checks_count_mismatch' }
if (@($s.qua95_checks | Where-Object { $_.name -notlike 'qua95_*' }).Count -gt 0) { $issues += 'qua95_checks_name_prefix_mismatch' }
if ($null -eq $s.qua95_issue_names) { $issues += 'qua95_issue_names_missing' }
if ($null -eq $s.non_qua95_issue_names) { $issues += 'non_qua95_issue_names_missing' }
if (@($s.qua95_issue_names).Count -ne [int]$s.qua95_issues_count) { $issues += 'qua95_issue_names_count_mismatch' }
if (@($s.non_qua95_issue_names).Count -ne [int]$s.non_qua95_issues_count) { $issues += 'non_qua95_issue_names_count_mismatch' }
if (@($s.qua95_issue_names | Where-Object { $_ -notlike 'qua95_*' }).Count -gt 0) { $issues += 'qua95_issue_names_prefix_mismatch' }
if (@($s.non_qua95_issue_names | Where-Object { $_ -like 'qua95_*' }).Count -gt 0) { $issues += 'non_qua95_issue_names_prefix_mismatch' }

if ($issues.Count -gt 0) {
    Write-Host ("status=critical issues={0}" -f ($issues -join ','))
    exit 1
}

Write-Host ("status=ok qua95_issues={0} non_qua95_issues={1}" -f $s.qua95_issues_count, $s.non_qua95_issues_count)
exit 0
