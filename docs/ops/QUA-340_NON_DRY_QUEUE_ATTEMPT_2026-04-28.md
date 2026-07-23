# QUA-340 Non-Dry Queue Attempt — 2026-04-28

Issue: QUA-340 `SRC04_S02a`  
Status: in_progress  
Scope: first non-dry queued execution attempt under de-dup lifecycle.

## Implementation Added

- New script: `infra/scripts/Invoke-PipelineQueuedSmokeRun.ps1`
- Purpose: run real `framework/scripts/run_smoke.ps1` attempt under queue contract:
  - de-dup preflight on `(ea_id, version, symbol, phase, sub_gate_config)`
  - queue transitions `enqueue -> claim -> running -> ack(final)`
  - durable evidence at `...\factory_runs\<ea>\<version>\<phase>\<symbol>\<run_key>\`

## QUA-340 Execution Evidence

Attempt tuple:
- `ea_id`: `QM5_3400`
- `version`: `v5.0.0-qua340`
- `symbol`: `EURUSD.DWX`
- `phase`: `P2`
- `sub_gate_config`: `qua340-smoke-004`
- `terminal`: `T2`

Final ack:
- `run_key`: `27b0f056f370e5e6a18a97de1280398f6fb0a7924da83312b8b6fb78249daf2e`
- `final_status`: `no_report`
- `htm_count`: `0`
- `report_bytes`: `0`

Evidence paths:
- queue ledger: `artifacts/qua-340-real/state/factory_run_queue_v1.jsonl`
- dedup registry: `artifacts/qua-340-real/state/factory_run_dedup_v1.csv`
- ack: `artifacts/qua-340-real/factory_runs/QM5_3400/v5.0.0-qua340/P2/EURUSD.DWX/27b0f056f370e5e6a18a97de1280398f6fb0a7924da83312b8b6fb78249daf2e/ack.json`
- smoke summary: `artifacts/qua-340-real/factory_runs/QM5_3400/v5.0.0-qua340/P2/EURUSD.DWX/27b0f056f370e5e6a18a97de1280398f6fb0a7924da83312b8b6fb78249daf2e/QM5_3400/20260428_085028/summary.json`

Summary result:
- `run_smoke.result=FAIL`
- `reason_classes=[REPORT_MISSING, INCOMPLETE_RUNS]`
- both runs returned `REPORT_MISSING` with no tester log copied.

## Blocked / Unblock

Blocked item:
- Production-baseline evidence for SRC04_S02a remains blocked by MT5 infra not producing report `.htm` in this environment.

Unblock owner:
- OWNER / DevOps

Unblock action:
- Validate T2 MT5 tester availability and portable run prerequisites on host (`D:\QM\mt5\T2\terminal64.exe`, tester log/report write path), then rerun with new `sub_gate_config` digest.
