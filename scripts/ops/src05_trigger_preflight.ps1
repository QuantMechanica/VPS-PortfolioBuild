param(
  [int]$FreshMinutes = 30,
  [string]$PipelineRoot = 'D:\QM\reports\pipeline\QM5_1017',
  [string]$EvidenceDir = 'C:\QM\repo\evidence',
  [int]$KeepArtifacts = 40
)

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
if(-not (Test-Path $EvidenceDir)){ New-Item -ItemType Directory -Path $EvidenceDir | Out-Null }
$evidenceLog = Join-Path $EvidenceDir ("qua1460_src05_trigger_wrapper_{0}.log" -f $ts)
$gateJsonPath = Join-Path $EvidenceDir ("qua1460_src05_gate_{0}.json" -f $ts)
$gateJsonLatest = Join-Path $EvidenceDir "qua1460_src05_gate_latest.json"
Start-Transcript -Path $evidenceLog -Force | Out-Null

$gateScript = 'C:\QM\repo\scripts\ops\src05_dispatch_gate.ps1'
$gateJson = powershell -ExecutionPolicy Bypass -File $gateScript -FreshMinutes $FreshMinutes -PipelineRoot $PipelineRoot -Json
$gateJson | Set-Content -Path $gateJsonPath
$gateJson | Set-Content -Path $gateJsonLatest
$gate = $gateJson | ConvertFrom-Json

"UTC_NOW=$($gate.utc_now)"
"ACTIVE=$($gate.active)"
"FACTORY_TERMINAL_COUNT=$($gate.factory_terminal_count)"
"EVIDENCE_LOG=$evidenceLog"
"GATE_JSON=$gateJsonPath"
"GATE_JSON_LATEST=$gateJsonLatest"

function Prune-Artifacts {
  param(
    [string]$Pattern,
    [int]$Keep
  )
  $items = Get-ChildItem -Path $EvidenceDir -File -Filter $Pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  $total = @($items).Count
  if($total -le $Keep){ return [pscustomobject]@{Pattern=$Pattern;Total=$total;Pruned=0} }
  $toDelete = $items | Select-Object -Skip $Keep
  $deleted = 0
  foreach($f in $toDelete){
    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
    $deleted++
  }
  return [pscustomobject]@{Pattern=$Pattern;Total=$total;Pruned=$deleted}
}

$p1 = Prune-Artifacts -Pattern "qua1460_src05_trigger_wrapper_*.log" -Keep $KeepArtifacts
$p2 = Prune-Artifacts -Pattern "qua1460_src05_gate_20*.json" -Keep $KeepArtifacts
"PRUNE_LOGS_PATTERN=$($p1.Pattern) TOTAL=$($p1.Total) PRUNED=$($p1.Pruned) KEEP=$KeepArtifacts"
"PRUNE_JSON_PATTERN=$($p2.Pattern) TOTAL=$($p2.Total) PRUNED=$($p2.Pruned) KEEP=$KeepArtifacts"

if(-not $gate.active){
  "ACTION=HOLD_NO_DISPATCH"
  Stop-Transcript | Out-Null
  exit 3
}

"ACTION=RUN_PREFLIGHT"
$utc = (Get-Date).ToUniversalTime().ToString('o')
Write-Output "PRECHECK_UTC=$utc"

$roots = 'D:\QM\mt5\T2','D:\QM\mt5\T3','D:\QM\mt5\T4','D:\QM\mt5\T5'
foreach($r in $roots){
  $exe = Join-Path $r 'terminal64.exe'
  if(Test-Path $exe){ Start-Process -FilePath $exe -WindowStyle Hidden }
}
Start-Sleep -Seconds 8

Get-Process terminal64 -ErrorAction SilentlyContinue |
  Select-Object Id,StartTime,Path |
  Sort-Object Path |
  Format-Table -AutoSize

$baseline = if(Test-Path $PipelineRoot){ (Get-ChildItem $PipelineRoot -Recurse -File -Filter report.htm | Measure-Object).Count } else { 0 }
"BASELINE_HTM=$baseline"
for($i=1; $i -le 12; $i++){
  Start-Sleep -Seconds 10
  $items = @()
  if(Test-Path $PipelineRoot){
    $items = Get-ChildItem $PipelineRoot -Recurse -File -Filter report.htm | Sort-Object LastWriteTime -Descending
  }
  $count = $items.Count
  $delta = $count - $baseline
  $latest = $items | Select-Object -First 1 FullName,Length,LastWriteTime
  Write-Output "TICK=$i COUNT=$count DELTA=$delta"
  if($latest){ $latest | Format-List }
  if($delta -gt 0){ break }
}

$state='D:\QM\reports\state\last_check_state.json'
if(Test-Path $state){
  $o=Get-Content $state -Raw | ConvertFrom-Json
  [pscustomobject]@{
    timestamp_utc=$o.timestamp_utc
    writer_pid=$o.writer_pid
    report_htm_total=$o.report_htm_total
    T1=$o.bl_progress.T1.terminal_pid
    T2=$o.bl_progress.T2.terminal_pid
    T3=$o.bl_progress.T3.terminal_pid
    T4=$o.bl_progress.T4.terminal_pid
    T5=$o.bl_progress.T5.terminal_pid
  } | Format-List
}

Stop-Transcript | Out-Null
