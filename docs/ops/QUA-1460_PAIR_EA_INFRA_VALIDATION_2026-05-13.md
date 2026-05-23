# QUA-1460 — Pair-EA Infrastructure Validation (SRC05 cohort)

Timestamp (UTC): 2026-05-13T11:19Z
Agent: Pipeline-Operator (`46fc11e5-7fc2-43f4-9a34-bde29e5dee3b`)

## Scope executed
- Validate factory terminal process coverage (T1-T5) and confirm no T6 process touch.
- Validate aggregator loop health (`last_check_state.json` freshness).
- Validate filesystem-vs-tracker consistency for report `.htm` counts.
- Validate pair-EA artifact availability for `QM5_1017` (SRC05 stat-arb cohort dependency) including T2/T3 binary parity.
- Validate disk headroom threshold.

## Evidence
- Factory terminals discovered on disk: `D:\QM\mt5\T1..T5`.
- Running `terminal64.exe` processes:
  - PID `1380` path `D:\QM\mt5\T1\terminal64.exe`
  - No `terminal64.exe` process from `T6` path detected.
- Disk free:
  - `D:` free `465.98 GB` (above 80 GB requirement; above 60 GB escalation threshold).
- Aggregator state before fix:
  - `D:\QM\reports\state\last_check_state.json` last write `2026-05-10 00:10:25` local.
  - `writer_pid=20056` not alive.
  - Scheduled task `\QM_AggregatorState_1min` had `Last Result=-2147024894` (bad task action executable resolution).
- Aggregator corrective action applied:
  1. One-shot run: `python311 C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py --once`
  2. Patched scheduled task action to explicit interpreter:
     - `"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe" "C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py" --once`
- Aggregator state after fix:
  - `last_check_state.json` advanced to writes at `2026-05-13T11:17:29Z` and `2026-05-13T11:17:47Z`.
  - `C:\QM\logs\aggregator\heartbeat.txt` updated with matching timestamps/iterations.
- Filesystem truth check:
  - Actual report count: `1273` `.htm`
  - Tracker `report_htm_total`: `1273`
  - Result: no discrepancy; no state reset required.
- Pair-EA artifacts (`QM5_1017 chan_pairs_stat_arb`) present:
  - EA + setfiles under `C:\QM\repo\framework\EAs\QM5_1017_chan_pairs_stat_arb\...`
  - Report artifacts under `D:\QM\reports\pipeline\QM5_1017\...` (`report.htm` count `131`).
  - T2/T3 ex5 parity:
    - `D:\QM\mt5\T2\MQL5\Experts\QM\QM5_1017_chan_pairs_stat_arb.ex5`
    - `D:\QM\mt5\T3\MQL5\Experts\QM\QM5_1017_chan_pairs_stat_arb.ex5`
    - SHA256 both: `3C5BB4F01E3C8AF034959FC37E1627A129BDA2E2C6AA1A82A1B13B9BCBE3521F`

## Current risk / gap
- Only T1 terminal process is currently running (`PID 1380`). T2-T5 are installed but not active at this instant.
- This is acceptable while idle, but for parallel factory throughput this remains a readiness gap.

## Next action
1. Keep `\QM_AggregatorState_1min` under observation for one full schedule cycle (confirm steady `Last Result` and per-minute file writes).
2. On next dispatched SRC05/P2 run, preflight start T2-T5 terminal processes and verify per-terminal report landing before launch.

## Heartbeat follow-up (UTC 2026-05-13T11:20Z)
- Scheduled task `\QM_AggregatorState_1min` health snapshot:
  - `State=Ready`
  - `LastRunTime=2026-05-13 13:19:19` local
  - `NextRunTime=2026-05-13 13:20:20` local
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
- Task action remains correctly pinned to explicit Python path:
  - Execute: `"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"`
  - Arguments: `"C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py" --once`
- Per-minute write stability check (filesystem truth):
  - `last_check_state.json` write advanced from `2026-05-13T11:19:04Z` to `2026-05-13T11:20:07Z` over a 75s sample window (`WriteAdvanced=True`).
- MT5 process scope remains compliant:
  - Running `terminal64.exe`: PID `1380` (`D:\QM\mt5\T1\terminal64.exe`)
  - No T6 process detected.

## Updated next action
1. Keep current idle posture while queue has no active parallel dispatch requiring T2-T5.
2. On next active SRC05/P2 dispatch, execute T2-T5 startup preflight and capture per-terminal report landing evidence in this same note.

## Heartbeat follow-up (UTC 2026-05-13T11:21:54Z)
- Wake trigger acknowledged: board comment confirmed aggregator stability; action remains event-driven for next SRC05/P2 dispatch.
- Active dispatch gate check:
  - Running `terminal64.exe`: PID `1380` only (T1).
  - T2/T3/T4/T5 `terminal64.exe`: not running.
  - No T6 process detected.
- Filesystem activity check (D:\QM\reports\pipeline):
  - Total `.htm` count: `1122`.
  - Most recent pipeline artifact write observed: `2026-05-09 16:54:48` local (`QM5_1014/P2/report.csv` family), i.e., no live report landing in this heartbeat window.
- Aggregator state freshness:
  - `D:\QM\reports\state\last_check_state.json` last write `2026-05-13 13:21:09` local (`timestamp_utc=2026-05-13T11:21:09Z`, `writer_pid=15028`).

## Decision
- No active SRC05/P2 dispatch is running at `2026-05-13T11:21:54Z`; T2-T5 startup preflight is deferred until dispatch activation to avoid unnecessary factory churn.

## Next action
1. On first active SRC05/P2 dispatch signal, immediately run T2-T5 startup preflight.
2. Capture per-terminal report-landing evidence (PID + first report path + write timestamp) in this document.

## Heartbeat follow-up (UTC 2026-05-13T11:23:20Z)
- Readiness preflight executed for upcoming SRC05/P2 dispatch.
- Runtime process scope:
  - Active `terminal64.exe`: T1 only (`PID 1380`, path `D:\QM\mt5\T1\terminal64.exe`).
  - T2/T3/T4/T5 terminals not running (expected idle posture).
  - T6 process not present.
- T2-T5 EA binary parity check (`QM5_1017_chan_pairs_stat_arb.ex5`):
  - T2: exists, `91546` bytes, SHA256 `3C5BB4F01E3C8AF034959FC37E1627A129BDA2E2C6AA1A82A1B13B9BCBE3521F`
  - T3: exists, `91546` bytes, SHA256 `3C5BB4F01E3C8AF034959FC37E1627A129BDA2E2C6AA1A82A1B13B9BCBE3521F`
  - T4: exists, `91546` bytes, SHA256 `3C5BB4F01E3C8AF034959FC37E1627A129BDA2E2C6AA1A82A1B13B9BCBE3521F`
  - T5: exists, `91546` bytes, SHA256 `3C5BB4F01E3C8AF034959FC37E1627A129BDA2E2C6AA1A82A1B13B9BCBE3521F`
- Aggregator tracker snapshot (`last_check_state.json`):
  - `timestamp_utc=2026-05-13T11:23:03Z`, `writer_pid=7400`
  - `bl_progress` terminal pids: `T1=1380`, `T2=none`, `T3=none`, `T4=none`, `T5=none`
  - `report_htm_total=1273`

## Decision
- Infrastructure readiness for SRC05 pair-EA binary deployment across T2-T5 is confirmed.
- Execution preflight (terminal start + per-terminal report landing proof) remains pending dispatch activation.

## Next action
1. On next SRC05/P2 dispatch activation, start T2-T5 and capture first landed report artifact per terminal (path + timestamp + byte size).
2. If any terminal fails to land first artifact within expected window, mark infra-blocked with terminal-specific evidence and unblock owner.

## Dispatch-Ready Command Pack (added 2026-05-13T11:24:00Z)
Use this block only when SRC05/P2 dispatch is confirmed active.

```powershell
# 0) Timestamp anchor
$utc = (Get-Date).ToUniversalTime().ToString('o')
Write-Output "PRECHECK_UTC=$utc"

# 1) Start T2-T5 terminals (factory only)
$roots = 'D:\QM\mt5\T2','D:\QM\mt5\T3','D:\QM\mt5\T4','D:\QM\mt5\T5'
foreach($r in $roots){
  $exe = Join-Path $r 'terminal64.exe'
  if(Test-Path $exe){ Start-Process -FilePath $exe -WindowStyle Hidden }
}
Start-Sleep -Seconds 8

# 2) PID evidence after start
Get-Process terminal64 -ErrorAction SilentlyContinue |
  Select-Object Id,StartTime,Path |
  Sort-Object Path |
  Format-Table -AutoSize

# 3) First report landing watcher (120s window, 10s tick)
$pipelineRoot = 'D:\QM\reports\pipeline\QM5_1017'
$baseline = if(Test-Path $pipelineRoot){ (Get-ChildItem $pipelineRoot -Recurse -File -Filter report.htm | Measure-Object).Count } else { 0 }
"BASELINE_HTM=$baseline"
for($i=1; $i -le 12; $i++){
  Start-Sleep -Seconds 10
  $items = @()
  if(Test-Path $pipelineRoot){
    $items = Get-ChildItem $pipelineRoot -Recurse -File -Filter report.htm | Sort-Object LastWriteTime -Descending
  }
  $count = $items.Count
  $delta = $count - $baseline
  $latest = $items | Select-Object -First 1 FullName,Length,LastWriteTime
  Write-Output "TICK=$i COUNT=$count DELTA=$delta"
  if($latest){ $latest | Format-List }
  if($delta -gt 0){ break }
}

# 4) Aggregator consistency snapshot
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
```

## Next action trigger
- Run the command pack immediately after first SRC05/P2 dispatch activation signal; paste resulting PID/report evidence into this document.

## Heartbeat follow-up (UTC 2026-05-13T11:26:34Z)
- Added dispatch gate checker script: `C:\QM\repo\scripts\ops\src05_dispatch_gate.ps1`
  - Purpose: return explicit `ACTIVE=True/False` before running the SRC05/P2 preflight pack.
  - Gate logic: factory `terminal64.exe` activity on T1-T5 (excluding T6) + at least one fresh `report.htm` under `D:\QM\reports\pipeline\QM5_1017` within lookback window.
- Execution evidence (`FreshMinutes=30`):
  - `ACTIVE=False` (exit code `3`)
  - `FACTORY_TERMINAL_COUNT=1` (T1 PID `1380`)
  - `LATEST_REPORT=none_within_window`

## Decision
- Dispatch remains inactive; preflight launch steps remain correctly deferred.

## Next action
1. Re-run `src05_dispatch_gate.ps1` on next heartbeat/wake.
2. When gate returns `ACTIVE=True`, execute Dispatch-Ready Command Pack immediately and append per-terminal landing evidence.

## Heartbeat follow-up (UTC 2026-05-13T11:27:41Z)
- Upgraded gate checker: `C:\QM\repo\scripts\ops\src05_dispatch_gate.ps1`
  - Added `-Json` mode for machine-readable orchestration.
  - Gate now accepts fresh `report.htm` OR fresh `report.csv` within lookback window.
- Validation run (text mode, `FreshMinutes=30`):
  - `ACTIVE=False` (exit code `3`)
  - `FACTORY_TERMINAL_COUNT=1` (`PID 1380`, T1)
  - `LATEST_HTM=none_within_window`
  - `LATEST_CSV=none_within_window`
- Validation run (JSON mode): payload emitted with
  - `active=false`
  - `has_recent_htm=false`
  - `has_recent_csv=false`

## Decision
- No SRC05/P2 activation signal yet from either report artifact type.

## Next action
1. Keep using `-Json` gate output as the trigger source.
2. Execute Dispatch-Ready Command Pack immediately when gate flips to `active=true`.

## Heartbeat follow-up (UTC 2026-05-13T11:28:32Z)
- Immediate liveness action executed:
  1. Ran gate now (`src05_dispatch_gate.ps1 -Json`) => `active=false`.
  2. Added auto-trigger wrapper `C:\QM\repo\scripts\ops\src05_trigger_preflight.ps1`.
     - Wrapper behavior: read gate JSON; if inactive -> hold exit `3`; if active -> run full preflight sequence automatically.
- Wrapper validation run output:
  - `UTC_NOW=2026-05-13T11:28:32.3719601Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `ACTION=HOLD_NO_DISPATCH`

## Decision
- No dispatch activation yet; automation is now in place to eliminate manual trigger delay.

## Next action
1. Re-run `src05_trigger_preflight.ps1` on next wake.
2. When gate flips active, wrapper will execute preflight and emit terminal/report evidence in one step.

## Heartbeat follow-up (UTC 2026-05-13T11:29:01Z)
- Re-ran `src05_trigger_preflight.ps1` as instructed.
- Concrete artifact captured:
  - `C:\QM\repo\evidence\qua1460_src05_trigger_20260513_112900.log`
- Run output summary:
  - `UTC_NOW=2026-05-13T11:29:01.3368789Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `ACTION=HOLD_NO_DISPATCH`
  - `EXIT_CODE=3`

## Decision
- Dispatch still inactive; hold branch executed correctly with durable log evidence.

## Heartbeat follow-up (UTC 2026-05-13T11:30:04Z)
- Updated wrapper `C:\QM\repo\scripts\ops\src05_trigger_preflight.ps1` to auto-capture a transcript log each run.
  - New params: `-EvidenceDir` (default `C:\QM\repo\evidence`)
  - Emits `EVIDENCE_LOG=<path>` in stdout.
- Validation run output:
  - `UTC_NOW=2026-05-13T11:30:04.8148261Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113004.log`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Evidence file verification:
  - `C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113004.log`
  - size `1003` bytes

## Decision
- Automated per-run artifact capture is now built into the trigger path; no manual tee step required.

## Heartbeat follow-up (UTC 2026-05-13T11:30:57Z)
- Re-executed auto-logging wrapper: `C:\QM\repo\scripts\ops\src05_trigger_preflight.ps1`
- Runtime output:
  - `UTC_NOW=2026-05-13T11:30:57.4364522Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113057.log`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Evidence file check:
  - `C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113057.log`
  - size `1003` bytes

## Decision
- Hold path remains stable and repeatable while dispatch is inactive.

## Heartbeat follow-up (UTC 2026-05-13T11:31:56Z)
- Executed integrated readiness sample (dispatch gate + disk + aggregator health).
- SRC05 trigger wrapper run:
  - `UTC_NOW=2026-05-13T11:31:56.1175859Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113155.log`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`
  - Status: above 80 GB requirement and above 60 GB escalation threshold.
- Aggregator schedule health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:31:31` local
  - `NextRunTime=2026-05-13 13:32:32` local

## Decision
- Infra remains stable; dispatch gate still inactive.

## Heartbeat follow-up (UTC 2026-05-13T11:32:59Z)
- Enhanced wrapper `src05_trigger_preflight.ps1` to persist gate JSON snapshots each run:
  - timestamped: `qua1460_src05_gate_<ts>.json`
  - stable latest: `qua1460_src05_gate_latest.json`
- Validation run output:
  - `UTC_NOW=2026-05-13T11:32:59.1308200Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113258.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113258.json`
  - `GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- File checks:
  - `C:\QM\repo\evidence\qua1460_src05_gate_20260513_113258.json` size `750` bytes
  - `C:\QM\repo\evidence\qua1460_src05_gate_latest.json` size `750` bytes

## Decision
- Dispatch remains inactive; JSON state artifacts are now available for quick diff/monitoring.

## Heartbeat follow-up (UTC 2026-05-13T11:33:54Z)
- Re-ran wrapper:
  - `UTC_NOW=2026-05-13T11:33:54.6528455Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113354.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113354.json`
  - `GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Corrected state-delta check (timestamped snapshots only, excluding `*_latest.json`):
  - `Prev=qua1460_src05_gate_20260513_113258.json`
  - `Latest=qua1460_src05_gate_20260513_113354.json`
  - `ActiveChanged=False`
  - `FactoryCountChanged=False`
  - `RecentHtmChanged=False`
  - `RecentCsvChanged=False`

## Decision
- Gate state unchanged across consecutive runs; hold behavior is consistent and deterministic.

## Heartbeat follow-up (UTC 2026-05-13T11:35:12Z)
- Updated wrapper `src05_trigger_preflight.ps1` with artifact-retention pruning.
  - New param: `-KeepArtifacts` (default `40`)
  - Prunes old files by pattern after each run:
    - `qua1460_src05_trigger_wrapper_*.log`
    - `qua1460_src05_gate_20*.json`
- Validation run (`-KeepArtifacts 10`):
  - `UTC_NOW=2026-05-13T11:35:12.7260976Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113512.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113512.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=6 PRUNED=0 KEEP=10`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=3 PRUNED=0 KEEP=10`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`

## Decision
- Hold path remains inactive; artifact growth is now bounded by wrapper-level retention policy.

## Heartbeat follow-up (UTC 2026-05-13T11:35:48Z)
- Wrapper run (`-KeepArtifacts 10`) completed.
- Output:
  - `UTC_NOW=2026-05-13T11:35:48.7810544Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113548.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113548.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=7 PRUNED=0 KEEP=10`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=0 KEEP=10`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`

## Decision
- Gate remains inactive; retention and artifact generation continue to behave as expected.

## Heartbeat follow-up (UTC 2026-05-13T11:36:19Z)
- Retention stress test run executed: `src05_trigger_preflight.ps1 -KeepArtifacts 3`
- Runtime output:
  - `UTC_NOW=2026-05-13T11:36:19.1167762Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113618.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113618.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=8 PRUNED=5 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=5 PRUNED=2 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Filesystem verification after prune:
  - wrapper logs remaining: `3`
  - timestamped gate JSON files remaining: `3`

## Decision
- Retention policy is effective and enforced on disk under low keep limits.

## Heartbeat follow-up (UTC 2026-05-13T11:37:19Z)
- Wrapper run repeated with active retention policy (`-KeepArtifacts 3`).
- Output:
  - `UTC_NOW=2026-05-13T11:37:19.5655385Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113719.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113719.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`

## Decision
- Dispatch remains inactive; rolling retention remains effective under repeated heartbeats.

## Heartbeat follow-up (UTC 2026-05-13T11:37:49Z)
- Executed wrapper with retention cap unchanged (`-KeepArtifacts 3`).
- Output:
  - `UTC_NOW=2026-05-13T11:37:49.6767939Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113749.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113749.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Post-run filesystem counts:
  - wrapper logs: `3`
  - timestamped gate JSON files: `3`

## Decision
- Dispatch still inactive; retention cap remains enforced exactly across successive runs.

## Heartbeat follow-up (UTC 2026-05-13T11:38:22Z)
- Wrapper run (`-KeepArtifacts 3`) output:
  - `UTC_NOW=2026-05-13T11:38:22.3944968Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113822.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113822.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Sequential snapshot delta check (post-run):
  - `PREV=qua1460_src05_gate_20260513_113749.json`
  - `LATEST=qua1460_src05_gate_20260513_113822.json`
  - `ACTIVE_CHANGED=False`
  - `FACTORY_COUNT_CHANGED=False`

## Decision
- No activation flip; hold state and factory count unchanged between consecutive snapshots.

## Heartbeat follow-up (UTC 2026-05-13T11:39:22Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:39:22.9125010Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_113922.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_113922.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:39:39` local
  - `NextRunTime=2026-05-13 13:40:40` local

## Decision
- Dispatch still inactive; aggregator schedule remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:40:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:40:21.0658821Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114020.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114020.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`

## Decision
- Dispatch inactive; disk remains far above escalation thresholds.

## Heartbeat follow-up (UTC 2026-05-13T11:41:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:41:19.4450385Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114119.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114119.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:41:41` local
  - `NextRunTime=2026-05-13 13:42:42` local

## Decision
- Dispatch inactive; aggregator remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:42:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:42:21.7943897Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114221.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114221.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - No additional `terminal64.exe` processes observed (no T6 path present).

## Decision
- Dispatch inactive; process scope remains compliant (factory T1 only, no T6 process).

## Heartbeat follow-up (UTC 2026-05-13T11:43:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:43:20.9861432Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114320.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114320.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- `QM5_1017` pipeline filesystem snapshot:
  - `HTM_COUNT=131`
  - latest report: `D:\QM\reports\pipeline\QM5_1017\P2\QM5_1017\20260508_062725\raw\run_02\report.htm`
  - latest report size: `29606` bytes
  - latest report mtime local: `2026-05-08 08:27:40`

## Decision
- Dispatch remains inactive; no new SRC05 report landing detected in filesystem.

## Heartbeat follow-up (UTC 2026-05-13T11:44:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:44:21.7742261Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114421.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114421.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:44:44` local
  - `NextRunTime=2026-05-13 13:45:45` local
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`

## Decision
- Dispatch remains inactive; infra health metrics are stable.

## Heartbeat follow-up (UTC 2026-05-13T11:45:22Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:45:22.2855169Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114521.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114521.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:45:45` local
  - `NextRunTime=2026-05-13 13:46:46` local

## Decision
- Dispatch still inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:46:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:46:20.8289933Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114620.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114620.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- `QM5_1017` filesystem snapshot:
  - `HTM_COUNT=131`
  - latest report: `D:\QM\reports\pipeline\QM5_1017\P2\QM5_1017\20260508_062725\raw\run_02\report.htm`
  - size: `29606` bytes
  - mtime local: `2026-05-08 08:27:40`

## Decision
- Dispatch remains inactive; no new SRC05 report landing detected.

## Heartbeat follow-up (UTC 2026-05-13T11:47:23Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:47:23.9049400Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114723.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114723.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Sequential snapshot delta check (post-run):
  - `PREV=qua1460_src05_gate_20260513_114620.json`
  - `LATEST=qua1460_src05_gate_20260513_114723.json`
  - `ACTIVE_CHANGED=False`
  - `FACTORY_COUNT_CHANGED=False`
  - `RECENT_HTM_CHANGED=False`
  - `RECENT_CSV_CHANGED=False`

## Decision
- No activation drift across consecutive snapshots; hold state remains deterministic.

## Heartbeat follow-up (UTC 2026-05-13T11:48:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:48:21.1203489Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114820.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114820.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:48:48` local
  - `NextRunTime=2026-05-13 13:49:49` local

## Decision
- Dispatch remains inactive; infra health remains stable.

## Heartbeat follow-up (UTC 2026-05-13T11:49:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:49:20.4581375Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_114920.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_114920.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process-scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch inactive; process scope remains compliant (no T6 process observed).

## Heartbeat follow-up (UTC 2026-05-13T11:50:25Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:50:25.7601892Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115025.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115025.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:50:50` local
  - `NextRunTime=2026-05-13 13:51:51` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:51:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:51:21.1580269Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115120.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115120.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- `QM5_1017` filesystem snapshot:
  - `HTM_COUNT=131`
  - latest report: `D:\QM\reports\pipeline\QM5_1017\P2\QM5_1017\20260508_062725\raw\run_02\report.htm`
  - size: `29606` bytes
  - mtime local: `2026-05-08 08:27:40`

## Decision
- Dispatch remains inactive; no new report landing detected.

## Heartbeat follow-up (UTC 2026-05-13T11:52:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:52:19.5539708Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115219.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115219.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:52:52` local
  - `NextRunTime=2026-05-13 13:53:53` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:53:25Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:53:25.6216095Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115325.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115325.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T11:54:23Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:54:23.7694393Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115423.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115423.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:54:54` local
  - `NextRunTime=2026-05-13 13:55:55` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:55:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:55:19.4892641Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115519.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115519.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`

## Decision
- Dispatch remains inactive; disk remains above thresholds.

## Heartbeat follow-up (UTC 2026-05-13T11:56:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:56:20.8047735Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115620.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115620.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:56:56` local
  - `NextRunTime=2026-05-13 13:57:57` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:57:16Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:57:16.8597006Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115716.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115716.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T11:57:46Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:57:46.6127854Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115746.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115746.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:57:57` local
  - `NextRunTime=2026-05-13 13:58:58` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T11:58:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:58:19.6667087Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115819.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115819.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- `QM5_1017` filesystem snapshot:
  - `HTM_COUNT=131`
  - latest report: `D:\QM\reports\pipeline\QM5_1017\P2\QM5_1017\20260508_062725\raw\run_02\report.htm`
  - size: `29606` bytes
  - mtime local: `2026-05-08 08:27:40`

## Decision
- Dispatch remains inactive; no new SRC05 report landing detected.

## Heartbeat follow-up (UTC 2026-05-13T11:59:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T11:59:21.0819832Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_115920.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_115920.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 13:59:59` local
  - `NextRunTime=2026-05-13 14:00:00` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:00:18Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:00:18.0664287Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120017.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120017.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:01:18Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:01:18.8154146Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120118.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120118.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:01:01` local
  - `NextRunTime=2026-05-13 14:02:02` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:02:17Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:02:17.8906267Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120217.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120217.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`

## Decision
- Dispatch remains inactive; disk remains stable and above thresholds.

## Heartbeat follow-up (UTC 2026-05-13T12:03:18Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:03:18.1300244Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120317.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120317.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:03:03` local
  - `NextRunTime=2026-05-13 14:04:04` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:04:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:04:20.9205287Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120420.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120420.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:05:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:05:20.2811530Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120519.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120519.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:05:05` local
  - `NextRunTime=2026-05-13 14:06:06` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:06:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:06:20.7521470Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120620.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120620.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:07:23Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:07:23.1284196Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120722.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120722.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:07:07` local
  - `NextRunTime=2026-05-13 14:08:08` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:08:21Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:08:21.1418870Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120820.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120820.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Disk headroom (`D:`):
  - `FreeGB=465.98`
  - `UsedGB=487.88`

## Decision
- Dispatch remains inactive; disk remains stable and above thresholds.

## Heartbeat follow-up (UTC 2026-05-13T12:09:18Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:09:18.6540097Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120918.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120918.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:09:09` local
  - `NextRunTime=2026-05-13 14:10:10` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:09:51Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:09:51.8610223Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_120951.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_120951.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:10:52Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:10:52.1244654Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121051.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121051.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:10:10` local
  - `NextRunTime=2026-05-13 14:11:11` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:11:49Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:11:49.6762985Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121149.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121149.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:12:48Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:12:48.9507719Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121248.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121248.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:12:12` local
  - `NextRunTime=2026-05-13 14:13:13` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:13:53Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:13:53.9154233Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121353.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121353.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:14:51Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:14:51.7206618Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121451.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121451.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:14:14` local
  - `NextRunTime=2026-05-13 14:15:15` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:15:52Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:15:52.3629244Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121552.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121552.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:16:52Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:16:52.4049037Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121652.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121652.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:16:16` local
  - `NextRunTime=2026-05-13 14:17:17` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:17:52Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:17:52.5527385Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121752.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121752.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:18:54Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:18:54.4604802Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121854.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121854.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:18:18` local
  - `NextRunTime=2026-05-13 14:19:19` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:19:52Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:19:52.3958731Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_121952.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_121952.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:20:53Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:20:53.2072687Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122052.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122052.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:20:20` local
  - `NextRunTime=2026-05-13 14:21:21` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:21:50Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:21:50.8738336Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122150.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122150.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:22:51Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:22:51.5984362Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122251.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122251.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:22:22` local
  - `NextRunTime=2026-05-13 14:23:23` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:23:52Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:23:52.0278261Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122351.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122351.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:24:51Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:24:51.1896152Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122450.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122450.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:24:24` local
  - `NextRunTime=2026-05-13 14:25:25` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:25:51Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:25:51.4338321Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122551.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122551.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:26:53Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:26:53.5024442Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122653.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122653.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:26:26` local
  - `NextRunTime=2026-05-13 14:27:27` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:28:34Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:28:34.3964542Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_122834.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_122834.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:33:28Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:33:28.9201528Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123328.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123328.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:33:33` local
  - `NextRunTime=2026-05-13 14:34:34` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:34:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:34:20.7550912Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123420.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123420.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:35:18Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:35:18.6510611Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123518.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123518.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:35:35` local
  - `NextRunTime=2026-05-13 14:36:36` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:36:18Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:36:18.8798229Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123618.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123618.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:37:25Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:37:25.4386282Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123725.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123725.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:37:37` local
  - `NextRunTime=2026-05-13 14:38:38` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:38:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:38:19.3019284Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123819.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123819.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:39:20Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:39:20.8103835Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_123920.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_123920.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:39:39` local
  - `NextRunTime=2026-05-13 14:40:40` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:40:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:40:19.5572550Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124019.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124019.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

## Heartbeat follow-up (UTC 2026-05-13T12:41:19Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:41:19.7164164Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124119.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124119.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- Aggregator scheduler health (`QM_AggregatorState_1min`):
  - `LastTaskResult=0`
  - `NumberOfMissedRuns=0`
  - `LastRunTime=2026-05-13 14:41:41` local
  - `NextRunTime=2026-05-13 14:42:42` local

## Decision
- Dispatch remains inactive; scheduler remains healthy.

## Heartbeat follow-up (UTC 2026-05-13T12:42:24Z)
- Wrapper run (`-KeepArtifacts 3`):
  - `UTC_NOW=2026-05-13T12:42:24.0616432Z`
  - `ACTIVE=False`
  - `FACTORY_TERMINAL_COUNT=1`
  - `EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124223.log`
  - `GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124223.json`
  - `PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3`
  - `PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3`
  - `ACTION=HOLD_NO_DISPATCH`
  - exit code `3`
- MT5 process scope snapshot:
  - `PID 1380` path `D:\QM\mt5\T1\terminal64.exe`
  - no additional `terminal64.exe` processes observed.

## Decision
- Dispatch remains inactive; process scope remains compliant.

### Heartbeat 2026-05-13 14:44:07 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: $exit
- Wrapper output:
`
UTC_NOW=05/13/2026 12:44:07
ACTIVE=False
FACTORY_TERMINAL_COUNT=1
EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124406.log
GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124406.json
GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json
PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3
PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3
ACTION=HOLD_NO_DISPATCH
`
- Scheduler (QM_AggregatorState_1min):
  - LastTaskResult=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastTaskResult)
  - NumberOfMissedRuns=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NumberOfMissedRuns)
  - LastRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastRunTime)
  - NextRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NextRunTime)
- MT5 process scope:
  - PID=1380 PATH=D:\QM\mt5\T1\terminal64.exe


### Heartbeat 2026-05-13 14:44:36 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: $exit
- Wrapper output:
`
UTC_NOW=05/13/2026 12:44:35
ACTIVE=False
FACTORY_TERMINAL_COUNT=1
EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124435.log
GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124435.json
GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json
PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3
PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3
ACTION=HOLD_NO_DISPATCH
`
- Scheduler (QM_AggregatorState_1min):
  - LastTaskResult=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastTaskResult)
  - NumberOfMissedRuns=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NumberOfMissedRuns)
  - LastRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastRunTime)
  - NextRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NextRunTime)
- MT5 process scope:
  - PID=1380 PATH=D:\QM\mt5\T1\terminal64.exe


### Heartbeat 2026-05-13 14:45:02 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: $exit
- Wrapper output:
`
UTC_NOW=05/13/2026 12:45:01
ACTIVE=False
FACTORY_TERMINAL_COUNT=1
EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124501.log
GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124501.json
GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json
PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3
PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3
ACTION=HOLD_NO_DISPATCH
`
- Scheduler (QM_AggregatorState_1min):
  - LastTaskResult=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastTaskResult)
  - NumberOfMissedRuns=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NumberOfMissedRuns)
  - LastRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastRunTime)
  - NextRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NextRunTime)
- MT5 process scope:
  - PID=1380 PATH=D:\QM\mt5\T1\terminal64.exe


### Heartbeat 2026-05-13 14:45:54 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: $exit
- Wrapper output:
`
UTC_NOW=05/13/2026 12:45:53
ACTIVE=False
FACTORY_TERMINAL_COUNT=1
EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124553.log
GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124553.json
GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json
PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3
PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3
ACTION=HOLD_NO_DISPATCH
`
- Scheduler (QM_AggregatorState_1min):
  - LastTaskResult=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastTaskResult)
  - NumberOfMissedRuns=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NumberOfMissedRuns)
  - LastRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).LastRunTime)
  - NextRunTime=$(MSFT_TaskDynamicInfo (TaskName = "QM_AggregatorState_1min", TaskPath).NextRunTime)
- MT5 process scope:
  - PID=1380 PATH=D:\QM\mt5\T1\terminal64.exe


### Heartbeat 2026-05-13 14:46:54 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:46:46, NextRun=05/13/2026 14:47:47
- WrapperTail: UTC_NOW=05/13/2026 12:46:53 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124653.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124653.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:47:15 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:47:47, NextRun=05/13/2026 14:48:48
- WrapperTail: UTC_NOW=05/13/2026 12:47:14 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124714.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124714.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:47:53 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:47:47, NextRun=05/13/2026 14:48:48
- MT5: PID=1380 PATH=D:\QM\mt5\T1\terminal64.exe
- WrapperTail: UTC_NOW=05/13/2026 12:47:52 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124752.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124752.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:48:20 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:48:48, NextRun=05/13/2026 14:49:49
- WrapperTail: UTC_NOW=05/13/2026 12:48:19 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124819.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124819.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:48:43 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:48:48, NextRun=05/13/2026 14:49:49
- WrapperTail: UTC_NOW=05/13/2026 12:48:42 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124842.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124842.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:49:20 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:49:49, NextRun=05/13/2026 14:50:50
- WrapperTail: UTC_NOW=05/13/2026 12:49:19 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124919.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124919.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:49:41 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:49:49, NextRun=05/13/2026 14:50:50
- WrapperTail: UTC_NOW=05/13/2026 12:49:40 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_124940.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_124940.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:50:02 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=267009, Missed=0, LastRun=05/13/2026 14:50:50, NextRun=05/13/2026 14:51:51
- WrapperTail: UTC_NOW=05/13/2026 12:50:01 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125001.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125001.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:50:51 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:50:50, NextRun=05/13/2026 14:51:51
- WrapperTail: UTC_NOW=05/13/2026 12:50:50 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125050.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125050.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:51:13 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:51:51, NextRun=05/13/2026 14:52:52
- WrapperTail: UTC_NOW=05/13/2026 12:51:13 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125112.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125112.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:51:35 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:51:51, NextRun=05/13/2026 14:52:52
- WrapperTail: UTC_NOW=05/13/2026 12:51:34 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125134.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125134.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:52:23 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:52:52, NextRun=05/13/2026 14:53:53
- WrapperTail: UTC_NOW=05/13/2026 12:52:23 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125222.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125222.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:52:48 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:52:52, NextRun=05/13/2026 14:53:53
- WrapperTail: UTC_NOW=05/13/2026 12:52:48 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125247.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125247.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:53:10 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:53:53, NextRun=05/13/2026 14:54:54
- WrapperTail: UTC_NOW=05/13/2026 12:53:09 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125309.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125309.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:53:51 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:53:53, NextRun=05/13/2026 14:54:54
- WrapperTail: UTC_NOW=05/13/2026 12:53:50 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125350.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125350.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:54:14 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:54:54, NextRun=05/13/2026 14:55:55
- WrapperTail: UTC_NOW=05/13/2026 12:54:13 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125413.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125413.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:54:36 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:54:54, NextRun=05/13/2026 14:55:55
- WrapperTail: UTC_NOW=05/13/2026 12:54:35 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125435.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125435.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:55:27 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:55:55, NextRun=05/13/2026 14:56:56
- WrapperTail: UTC_NOW=05/13/2026 12:55:26 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125526.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125526.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:55:49 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:55:55, NextRun=05/13/2026 14:56:56
- WrapperTail: UTC_NOW=05/13/2026 12:55:49 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125548.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125548.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:56:13 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:56:56, NextRun=05/13/2026 14:57:57
- WrapperTail: UTC_NOW=05/13/2026 12:56:12 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125612.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125612.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:56:53 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:56:56, NextRun=05/13/2026 14:57:57
- WrapperTail: UTC_NOW=05/13/2026 12:56:53 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125652.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125652.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:57:17 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:57:57, NextRun=05/13/2026 14:58:58
- WrapperTail: UTC_NOW=05/13/2026 12:57:16 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125716.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125716.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:57:38 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:57:57, NextRun=05/13/2026 14:58:58
- WrapperTail: UTC_NOW=05/13/2026 12:57:38 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125737.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125737.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:58:22 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:58:58, NextRun=05/13/2026 14:59:59
- WrapperTail: UTC_NOW=05/13/2026 12:58:22 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125821.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125821.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:58:49 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:58:58, NextRun=05/13/2026 14:59:59
- WrapperTail: UTC_NOW=05/13/2026 12:58:48 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125848.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125848.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:59:11 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:59:59, NextRun=05/13/2026 15:00:00
- WrapperTail: UTC_NOW=05/13/2026 12:59:11 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125910.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125910.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 14:59:59 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 14:59:59, NextRun=05/13/2026 15:00:00
- WrapperTail: UTC_NOW=05/13/2026 12:59:58 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_125958.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_125958.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:00:22 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:00:00, NextRun=05/13/2026 15:01:01
- WrapperTail: UTC_NOW=05/13/2026 13:00:22 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130021.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130021.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:00:49 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:00:00, NextRun=05/13/2026 15:01:01
- WrapperTail: UTC_NOW=05/13/2026 13:00:49 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130049.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130049.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:01:26 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:01:01, NextRun=05/13/2026 15:02:02
- WrapperTail: UTC_NOW=05/13/2026 13:01:25 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130125.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130125.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:01:48 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:01:01, NextRun=05/13/2026 15:02:02
- WrapperTail: UTC_NOW=05/13/2026 13:01:48 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130147.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130147.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:02:09 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:02:02, NextRun=05/13/2026 15:03:03
- WrapperTail: UTC_NOW=05/13/2026 13:02:09 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130209.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130209.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:03:36 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:03:03, NextRun=05/13/2026 15:04:04
- WrapperTail: UTC_NOW=05/13/2026 13:03:35 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130335.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130335.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:04:09 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:04:04, NextRun=05/13/2026 15:05:05
- WrapperTail: UTC_NOW=05/13/2026 13:04:08 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130408.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130408.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:04:31 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:04:04, NextRun=05/13/2026 15:05:05
- WrapperTail: UTC_NOW=05/13/2026 13:04:31 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130430.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130430.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:05:20 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:05:05, NextRun=05/13/2026 15:06:06
- WrapperTail: UTC_NOW=05/13/2026 13:05:19 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130519.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130519.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:05:41 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:05:05, NextRun=05/13/2026 15:06:06
- WrapperTail: UTC_NOW=05/13/2026 13:05:41 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130540.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130540.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:06:03 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:06:06, NextRun=05/13/2026 15:07:07
- WrapperTail: UTC_NOW=05/13/2026 13:06:03 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130603.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130603.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:06:52 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:06:06, NextRun=05/13/2026 15:07:07
- WrapperTail: UTC_NOW=05/13/2026 13:06:51 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130651.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130651.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:07:16 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:07:07, NextRun=05/13/2026 15:08:08
- WrapperTail: UTC_NOW=05/13/2026 13:07:15 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130715.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130715.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:07:38 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:07:07, NextRun=05/13/2026 15:08:08
- WrapperTail: UTC_NOW=05/13/2026 13:07:37 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130737.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130737.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:08:23 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:08:08, NextRun=05/13/2026 15:09:09
- WrapperTail: UTC_NOW=05/13/2026 13:08:22 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130822.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130822.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:08:49 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:08:08, NextRun=05/13/2026 15:09:09
- WrapperTail: UTC_NOW=05/13/2026 13:08:48 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130848.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130848.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:09:12 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:09:09, NextRun=05/13/2026 15:10:10
- WrapperTail: UTC_NOW=05/13/2026 13:09:11 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130911.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130911.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:09:51 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:09:09, NextRun=05/13/2026 15:10:10
- WrapperTail: UTC_NOW=05/13/2026 13:09:51 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_130951.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_130951.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:10:15 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:10:10, NextRun=05/13/2026 15:11:11
- WrapperTail: UTC_NOW=05/13/2026 13:10:14 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131014.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131014.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:10:37 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:10:10, NextRun=05/13/2026 15:11:11
- WrapperTail: UTC_NOW=05/13/2026 13:10:36 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131036.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131036.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:11:30 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:11:11, NextRun=05/13/2026 15:12:12
- WrapperTail: UTC_NOW=05/13/2026 13:11:30 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131129.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131129.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:11:54 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:11:11, NextRun=05/13/2026 15:12:12
- WrapperTail: UTC_NOW=05/13/2026 13:11:54 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131153.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131153.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:12:17 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:12:12, NextRun=05/13/2026 15:13:13
- WrapperTail: UTC_NOW=05/13/2026 13:12:17 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131216.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131216.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:12:54 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:12:12, NextRun=05/13/2026 15:13:13
- WrapperTail: UTC_NOW=05/13/2026 13:12:53 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131253.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131253.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:13:16 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:13:13, NextRun=05/13/2026 15:14:14
- WrapperTail: UTC_NOW=05/13/2026 13:13:15 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131315.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131315.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:13:38 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:13:13, NextRun=05/13/2026 15:14:14
- WrapperTail: UTC_NOW=05/13/2026 13:13:38 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131337.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131337.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:14:24 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:14:14, NextRun=05/13/2026 15:15:15
- WrapperTail: UTC_NOW=05/13/2026 13:14:24 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131423.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131423.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:14:47 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:14:14, NextRun=05/13/2026 15:15:15
- WrapperTail: UTC_NOW=05/13/2026 13:14:47 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131447.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131447.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:15:11 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:15:15, NextRun=05/13/2026 15:16:16
- WrapperTail: UTC_NOW=05/13/2026 13:15:11 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131510.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131510.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:15:53 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:15:15, NextRun=05/13/2026 15:16:16
- WrapperTail: UTC_NOW=05/13/2026 13:15:53 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131552.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131552.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:16:17 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:16:16, NextRun=05/13/2026 15:17:17
- WrapperTail: UTC_NOW=05/13/2026 13:16:16 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131616.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131616.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:16:41 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:16:16, NextRun=05/13/2026 15:17:17
- WrapperTail: UTC_NOW=05/13/2026 13:16:40 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131640.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131640.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:17:23 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:17:17, NextRun=05/13/2026 15:18:18
- WrapperTail: UTC_NOW=05/13/2026 13:17:23 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131722.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131722.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:17:48 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:17:17, NextRun=05/13/2026 15:18:18
- WrapperTail: UTC_NOW=05/13/2026 13:17:47 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131747.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131747.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:18:17 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:18:18, NextRun=05/13/2026 15:19:19
- WrapperTail: UTC_NOW=05/13/2026 13:18:16 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131816.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131816.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:18:54 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:18:18, NextRun=05/13/2026 15:19:19
- WrapperTail: UTC_NOW=05/13/2026 13:18:53 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131853.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131853.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:19:17 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:19:19, NextRun=05/13/2026 15:20:20
- WrapperTail: UTC_NOW=05/13/2026 13:19:16 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131916.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131916.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:19:41 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:19:19, NextRun=05/13/2026 15:20:20
- WrapperTail: UTC_NOW=05/13/2026 13:19:41 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_131940.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_131940.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:20:23 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:20:20, NextRun=05/13/2026 15:21:21
- WrapperTail: UTC_NOW=05/13/2026 13:20:23 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132022.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132022.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:20:51 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:20:20, NextRun=05/13/2026 15:21:21
- WrapperTail: UTC_NOW=05/13/2026 13:20:51 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132050.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132050.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:21:19 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:21:21, NextRun=05/13/2026 15:22:22
- WrapperTail: UTC_NOW=05/13/2026 13:21:18 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132118.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132118.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:21:52 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:21:21, NextRun=05/13/2026 15:22:22
- WrapperTail: UTC_NOW=05/13/2026 13:21:52 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132151.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132151.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:22:17 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:22:22, NextRun=05/13/2026 15:23:23
- WrapperTail: UTC_NOW=05/13/2026 13:22:16 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132216.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132216.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:22:45 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:22:22, NextRun=05/13/2026 15:23:23
- WrapperTail: UTC_NOW=05/13/2026 13:22:44 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132244.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132244.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH


### Heartbeat 2026-05-13 15:23:22 +02:00
- Command: src05_trigger_preflight.ps1 -KeepArtifacts 3
- ExitCode: 3
- Scheduler: LastTaskResult=0, Missed=0, LastRun=05/13/2026 15:23:23, NextRun=05/13/2026 15:24:24
- WrapperTail: UTC_NOW=05/13/2026 13:23:21 | ACTIVE=False | FACTORY_TERMINAL_COUNT=1 | EVIDENCE_LOG=C:\QM\repo\evidence\qua1460_src05_trigger_wrapper_20260513_132321.log | GATE_JSON=C:\QM\repo\evidence\qua1460_src05_gate_20260513_132321.json | GATE_JSON_LATEST=C:\QM\repo\evidence\qua1460_src05_gate_latest.json | PRUNE_LOGS_PATTERN=qua1460_src05_trigger_wrapper_*.log TOTAL=4 PRUNED=1 KEEP=3 | PRUNE_JSON_PATTERN=qua1460_src05_gate_20*.json TOTAL=4 PRUNED=1 KEEP=3 | ACTION=HOLD_NO_DISPATCH

