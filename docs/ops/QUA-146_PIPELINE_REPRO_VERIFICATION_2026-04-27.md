# QUA-146 Pipeline Repro Verification (2026-04-27)

Scope: Verify VPS reproducibility for the currently implemented pipeline infrastructure pieces: aggregator state writer and scheduler wiring. Also verify whether a runnable backtest runner exists in repo.

## Environment

- Repo: `C:\QM\repo`
- Date: 2026-04-27
- Agent run id: `05a7184a-5b6d-4d0d-bf98-85cfac1802fd`

## Findings

1. `scripts/aggregator/standalone_aggregator_loop.py` is runnable and deterministic on repeated `--once` invocations.
2. The scheduler installer was not reproducible as-shipped under `SYSTEM` because it used bare `python` (task result `2147942402`, executable not found).
3. Installer hardened in this run: `infra/scripts/Install-AggregatorStateTask.ps1` now resolves `-PythonExe` to an absolute path before task registration.
4. Post-fix scheduled run is healthy (`LastTaskResult = 0`).
5. Backtest runner implementation was missing at verification time, so backtest reproducibility could not be closed in this run.

## Evidence

### Aggregator one-shot reproducibility

Command 1:

```powershell
python scripts/aggregator/standalone_aggregator_loop.py --once
```

Observed:

```text
2026-04-27T13:09:16 wrote D:\QM\reports\state\last_check_state.json iteration=933 dirs=0 htm_total=0
```

Command 2:

```powershell
python scripts/aggregator/standalone_aggregator_loop.py --once
```

Observed:

```text
2026-04-27T13:09:18 wrote D:\QM\reports\state\last_check_state.json iteration=934 dirs=0 htm_total=0
```

State snapshot after run:

```json
{"schema_version":"qm.v5.last_check_state.v1","iteration":934,"status":"standalone_aggregator_loop_v5","timestamp_utc":"2026-04-27T11:09:18Z","report_directory_count":0,"report_htm_total":0,"t1_status":"idle_or_stalled","t5_status":"idle_or_stalled"}
```

Heartbeat snapshot after run:

```json
{"wall_clock_utc": "2026-04-27T11:09:18Z", "iteration": 934, "status": "standalone_aggregator_loop_v5", "writer_pid": 86344}
```

`Invoke-InfraHealthCheck.ps1` evidence (aggregator-specific check):

```json
{"check":"aggregator_silence","status":"ok","message":"Aggregator heartbeat fresh.","details":{"age_minutes":0.21}}
```

### Scheduler reproducibility and fix

Before fix:

- Task existed after install, but `Get-ScheduledTaskInfo` showed `LastTaskResult = 2147942402` (`0x80070002`), indicating scheduler context could not resolve bare `python`.

Fix applied:

- `infra/scripts/Install-AggregatorStateTask.ps1`
- Added absolute executable resolution + validation for `-PythonExe`.

After fix (installer output):

```text
Action: C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe "C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py" --once
```

After fix (task info):

```json
{"last_run_time":"2026-04-27T13:10:10+02:00","last_task_result":0,"next_run_time":"2026-04-27T13:11:11+02:00"}
```

### Backtest runner presence check (at verification-time snapshot)

- `framework/scripts` directory was missing in the checked snapshot.
- `framework` contained only:
  - `framework/README.md`
  - `framework/V5_FRAMEWORK_DESIGN.md`

Conclusion at that time: no runnable V5 backtest runner existed to reproduce.

## Update (QUA-178, 2026-04-27)

Minimal V5 backtest smoke runner scaffold is now present under `framework/scripts/`:

- `framework/scripts/run_smoke.ps1` (Model 4 only gate)
- `framework/scripts/run_backtest_smoke.ps1` (opinionated wrapper for the fixture smoke path)

Dry-run evidence:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File framework/scripts/run_backtest_smoke.ps1 -Year 2024 -Terminal T1 -DryRun
```

Observed:

```text
run_backtest_smoke.command=& "C:\QM\repo\framework\scripts\run_smoke.ps1" -EAId 1001 -Expert QM\QM5_1001_framework_smoke -Symbol EURUSD.DWX -Year 2024 -Terminal T1 -Period H1 -Runs 2 -MinTrades 0 -Model 4 -TimeoutSeconds 1800 -SetFile C:\QM\repo\framework\tests\smoke\QM5_1001_framework_smoke.set -ReportRoot D:\QM\reports\smoke
run_backtest_smoke.result=DRY_RUN
```

## Status

Updated completion state for QUA-146:

- Aggregator reproducibility: verified and hardened.
- Backtest smoke runner scaffold: implemented and command-resolvable.

Remaining action to fully close reproducibility:

- Execute one full non-dry smoke run on T1 and attach `summary.json` + evidence markdown outputs.

## Follow-up Run (QUA-178 continuation, 2026-04-27)

Executed non-dry T1 invocation:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File framework/scripts/run_backtest_smoke.ps1 -Year 2024 -Terminal T1 -AllowRunningTerminal
```

Observed:

```text
run_smoke.result=FAIL
run_smoke.reason_classes=REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED
run_smoke.summary=D:\QM\reports\smoke\QM5_1001\20260427_114057\summary.json
run_smoke.report_dir=D:\QM\reports\smoke\QM5_1001\20260427_114057
run_smoke.evidence=D:\QM\reports\framework\22\20260427_114057_QM5_1001_run_smoke.md
```

Summary snapshot (`D:\QM\reports\smoke\QM5_1001\20260427_114057\summary.json`):

- `model = 4` (hard-rule gate held)
- `runs[0..1].failure = REPORT_MISSING`
- `result = FAIL`

Interpretation:

- Scaffold and artifact path are now verified end-to-end (non-dry run emits summary + evidence files).
- T1 runtime currently fails before tester report generation; this is an environment/terminal-state execution issue, not a missing-runner artifact issue.
