# QUA-649 Unblock Runbook (Framework Ops)

## Goal
Restore deterministic smoke execution isolation for QM5_1003/QM5_1004 and allow Stage A completion.

## Preconditions
- Review evidence index:
  - C:\QM\repo\framework\EAs\QM5_1003_davey_baseline_3bar\QUA-649_EVIDENCE_INDEX_2026-05-01.md

## Step 1: Ensure T1 terminal isolation
- Identify active conflicting processes:
  - Get-CimInstance Win32_Process | ? { $_.Name -in @('terminal64.exe','metatester64.exe') -and ($_.CommandLine -match 'D:\\QM\\mt5\\T1') } | select Name,ProcessId,CommandLine
- Stop conflicting processes before smoke:
  - Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue
  - Stop-Process -Name metatester64 -Force -ErrorAction SilentlyContinue

## Step 2: Re-run smoke without AllowRunningTerminal
- QM5_1003:
  - C:\QM\repo\framework\scripts\run_smoke.ps1 -EAId 1003 -Symbol EURUSD.DWX -Year 2024 -Terminal T1 -Period H1 -Runs 2 -MinTrades 0 -Model 4
- QM5_1004:
  - C:\QM\repo\framework\scripts\run_smoke.ps1 -EAId 1004 -Symbol EURUSD.DWX -Year 2024 -Terminal T1 -Period H1 -Runs 2 -MinTrades 0 -Model 4

## Step 3: Validate artifact materialization
- For each new run tag, confirm under D:\QM\reports\smoke\QM5_1003\<run_tag>\raw and D:\QM\reports\smoke\QM5_1004\<run_tag>\raw:
  - report.htm exists and size > 0
  - tester day log exists (YYYYMMDD.log)

## Step 4: Resume QUA-649 pipeline handoff
- If both smoke runs PASS or produce valid artifacts, notify QUA-649 to rerun Stage A and proceed to baseline backtests.

## Expected previous failure signature (for comparison)
- REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED
- only tester.ini present in raw run folders
- run-tag/report-path drift under D:\QM\mt5\T1
