# QUA-246 Queue/De-Dup Dry-Run Evidence (2026-04-27)

Status: completed (implementation smoke), not the first production backtest confirmation.

## Purpose

Prove the documented queue/de-dup contract is executable end-to-end for:

- `enqueue -> claim -> running -> ack`
- tuple de-dup row creation
- run-evidence directory creation

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\Invoke-PipelineQueueDryRun.ps1 `
  -StateRoot artifacts\qua-246\state `
  -EvidenceRoot artifacts\qua-246\factory_runs `
  -EaId QM5_2460 `
  -Version v5.0.0-qua246 `
  -Symbol EURUSD `
  -Phase P2 `
  -SubGateConfig qua246-dryrun-001 `
  -Terminal T2 `
  -FinalStatus succeeded `
  -OutJson artifacts\qua-246\queue_dryrun_result_2026-04-27.json
```

## Result Summary

- `status`: `ok`
- `run_key`: `529207171fb2573c5c263e4e660e0a09ef2bff1910fd65318b2873fd1c9f7d34`
- `terminal`: `T2`
- `final_status`: `succeeded`

## De-Dup Enforcement Check

Re-running the same tuple with identical `(ea_id, version, symbol, phase, sub_gate_config)` failed as expected:

- error: `Duplicate tuple detected for run_key=529207171fb2573c5c263e4e660e0a09ef2bff1910fd65318b2873fd1c9f7d34`
- exit code: `1`

## Produced Artifacts

- `artifacts/qua-246/state/factory_run_dedup_v1.csv`
- `artifacts/qua-246/state/factory_run_queue_v1.jsonl`
- `artifacts/qua-246/state/factory_dispatch_state_v1.json`
- `artifacts/qua-246/queue_dryrun_result_2026-04-27.json`
- `artifacts/qua-246/factory_runs/QM5_2460/v5.0.0-qua246/P2/EURUSD/529207171fb2573c5c263e4e660e0a09ef2bff1910fd65318b2873fd1c9f7d34/`
  - `dispatch.json`
  - `runner_stdout.log`
  - `runner_stderr.log`
  - `pid_snapshot.json`
  - `result_01.htm`
  - `report_manifest.json`
  - `ack.json`

## Notes

- This run is a controlled dry-run in repo-local `artifacts/qua-246`, not VPS production `D:\QM\reports`.
- QUA-246 acceptance item "first subsequent backtest run uses new de-dup queue" remains open and requires a real cohort run with issue-thread confirmation.
