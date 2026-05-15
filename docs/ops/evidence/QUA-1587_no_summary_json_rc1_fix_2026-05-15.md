# QUA-1587 no_summary_json:rc=1 investigation + fix (2026-05-15)

## Root cause reproduced

Worker-like environment with empty TEMP caused `run_smoke.ps1` to exit before summary emission when dispatch temp job file path was built from `$env:TEMP`.

Repro command:

```powershell
$env:TEMP=''
pwsh -NoProfile -File C:\QM\repo\framework\scripts\run_smoke.ps1 \
  -EAId 1001 -Expert 'QM\\QM5_1001_framework_smoke' -Symbol 'EURUSD.DWX' \
  -Year 2024 -Terminal any -Period H1 -Runs 2 -MinTrades 0 -Model 4 \
  -TimeoutSeconds 60 -SetFile C:\QM\repo\framework\tests\smoke\QM5_1001_framework_smoke.set \
  -ReportRoot D:\QM\reports\smoke\qua1587_repro
```

Observed pre-fix failure:
- `Cannot bind argument to parameter 'Path' because it is an empty string.`
- exit code `1`
- no `run_smoke.summary=...` output

## Fix

`framework/scripts/run_smoke.ps1`
- Added `Get-QmTempDirectory` fallback resolver (`TEMP` -> `TMP` -> system temp -> `D:\QM\tmp` -> `C:\QM\tmp`).
- Replaced direct `$env:TEMP` use in dispatch temp job creation with `Get-QmTempDirectory`.

## Post-fix proof (same constrained env)

Same command now emits summary path:

- `run_smoke.dispatch_status=scheduled`
- `run_smoke.dispatch_terminal=T5`
- `run_smoke.result=FAIL`
- `run_smoke.summary=D:\QM\reports\smoke\qua1587_repro\QM5_1001\20260515_105140\summary.json`
- `run_smoke.dispatch_complete_status=released`

This proves rc=1 no-summary failure mode is removed for this worker-context condition.

## Worker-pool rerun note

I also patched `framework/scripts/mt5_worker.py` to better fit pool execution:
- pass `-AllowRunningTerminal` to `run_smoke`.
- pass explicit `-TimeoutSeconds` (new `--timeout-seconds`, default 60).

A scratch DB rerun job was launched (`C:\QM\repo\.scratch\qua1587_worker_rerun.db`, job_id `qua1587-job-2`), but remained `running` beyond this heartbeat window, so `status=done` capture is still pending in this run.
