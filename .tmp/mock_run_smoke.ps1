param(
 [int]$EAId,[string]$Symbol,[int]$Year,[string]$Period,[string]$Terminal,[int]$Runs,[int]$MinTrades,[string]$SetFile,[string]$ReportRoot='D:/QM/reports/smoke'
)
$dir = Join-Path $env:TEMP ("mock_smoke_{0}_{1}_{2}" -f $EAId,$Symbol.Replace('.','_'),[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$summary = Join-Path $dir 'summary.json'
$obj = [ordered]@{ result='PASS'; symbol=$Symbol; year=$Year; terminal=$Terminal; runs=@(@{status='OK'; profit_factor=1.23; total_trades=100}) }
$obj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summary -Encoding utf8
Start-Sleep -Milliseconds 500
Write-Output "run_smoke.summary=$summary"
exit 0
