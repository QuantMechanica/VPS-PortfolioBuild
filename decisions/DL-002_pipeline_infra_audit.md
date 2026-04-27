# DL-002 Pipeline Infrastructure Audit (QUA-146)
Date: 2026-04-27
Owner: CTO
Issue: QUA-146

## Scope
Audit whether current VPS pipeline infrastructure is reproducible from scratch for:
- aggregator state writer
- backtest runner

This is an audit, not a framework build.

## What exists and runs today

1. Aggregator script exists and runs:
   - `scripts/aggregator/standalone_aggregator_loop.py`
   - Verified with two consecutive `--once` runs (`iteration 933 -> 934`) writing `D:\QM\reports\state\last_check_state.json`.
2. Aggregator heartbeat is produced and consumed by infra health:
   - `C:\QM\logs\aggregator\heartbeat.txt`
   - `infra/monitoring/Invoke-InfraHealthCheck.ps1` reports `aggregator_silence = ok` after run.
3. Aggregator scheduler installer exists and is idempotent:
   - `infra/scripts/Install-AggregatorStateTask.ps1`

## What was undocumented/manual or non-reproducible

1. Scheduler action used bare `python` under `SYSTEM`, causing task execution failure (`LastTaskResult = 2147942402`, executable not found in that context).
2. This creates host-profile dependence and breaks fresh-VPS reproducibility.

## Hardening applied in this audit

1. Updated `infra/scripts/Install-AggregatorStateTask.ps1`:
   - resolves `-PythonExe` to an absolute path when a command name is provided;
   - validates executable exists before task registration;
   - registers task action with absolute executable path.
2. Reinstalled task and verified successful run:
   - task action now points to `C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe`
   - `Get-ScheduledTaskInfo` shows `LastTaskResult = 0`.

## What is missing from a fresh-VPS perspective

1. Backtest runner implementation is missing in repo:
   - `framework/scripts` directory does not exist.
   - `framework/` currently contains design docs only (`README.md`, `V5_FRAMEWORK_DESIGN.md`).
2. Therefore backtest-runner reproducibility cannot be verified yet.

## Recommended next steps before Phase 2 framework implementation

1. Keep this issue blocked for full closure until a runnable V5 backtest/smoke runner exists under `framework/scripts`.
2. Once runner exists, execute a minimal deterministic reproduction checklist on T1:
   - runner invocation with Model 4 guard active;
   - fixed-risk baseline path validation;
   - artifact/state output schema validation;
   - second run reproducibility check (same inputs, same verdict fields except timestamps/run ids).
3. Capture that run in a follow-up decision doc and close QUA-146.

## Evidence index

- `docs/ops/QUA-146_PIPELINE_REPRO_VERIFICATION_2026-04-27.md`
- `infra/scripts/Install-AggregatorStateTask.ps1`
- `scripts/aggregator/standalone_aggregator_loop.py`
