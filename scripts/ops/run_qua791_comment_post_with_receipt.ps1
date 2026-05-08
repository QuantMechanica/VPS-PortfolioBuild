param(
  [string]$PythonExe = 'python'
)

$ts = Get-Date -Format 'yyyy-MM-ddTHHmmssK'
$outDir = 'C:/QM/repo/docs/ops'
$receipt = Join-Path $outDir ('QUA-791_COMMENT_POST_RECEIPT_' + ($ts -replace ':', '') + '.md')
$script = 'C:/QM/repo/scripts/ops/post_qua791_comment.py'

$cmd = $PythonExe + ' ' + $script
$output = & $PythonExe $script 2>&1
$exitCode = $LASTEXITCODE

$lines = @()
$lines += '# QUA-791 Comment Post Receipt'
$lines += ''
$lines += ('- Timestamp: ' + $ts)
$lines += ('- Command: ' + $cmd)
$lines += ('- Exit code: ' + $exitCode)
$lines += ''
$lines += '## Output'
$lines += '```text'
$lines += (($output | Out-String).TrimEnd())
$lines += '```'

$lines | Set-Content -Path $receipt -Encoding UTF8

Write-Output ('RECEIPT=' + $receipt)
if ($exitCode -ne 0) {
  exit $exitCode
}
