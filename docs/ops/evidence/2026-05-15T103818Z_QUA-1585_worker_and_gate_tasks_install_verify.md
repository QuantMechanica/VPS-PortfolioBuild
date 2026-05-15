# QUA-1585 / QUA-1582 Child B — Worker+Gate Scheduled Task Install Verify

- timestamp_utc: 2026-05-15T10:38:18.0648532Z
- scope: Install and verify QM_MT5_Worker_T1..T5 and QM_GateEvaluator_5min
- out-of-scope: T6

## Commands

- `powershell -ExecutionPolicy Bypass -File framework/scripts/register_mt5_workers.ps1`
- `schtasks /Query /TN \QM_MT5_Worker_T1 /V /FO LIST`
- `schtasks /Query /TN \QM_MT5_Worker_T2 /V /FO LIST`
- `schtasks /Query /TN \QM_MT5_Worker_T3 /V /FO LIST`
- `schtasks /Query /TN \QM_MT5_Worker_T4 /V /FO LIST`
- `schtasks /Query /TN \QM_MT5_Worker_T5 /V /FO LIST`
- `schtasks /Query /TN \QM_GateEvaluator_5min /V /FO LIST`

## Task-State Evidence

- All six tasks exist and are `Status: Ready` with `Run As User: qm-admin`.
- Worker tasks T1..T5 run every 1 minute, `Task To Run: python framework/scripts/mt5_worker.py --terminal T*`.
- Gate evaluator task runs every 5 minutes, `Task To Run: python framework/scripts/gate_evaluator.py`.
- Scheduler settings from query output:
  - Worker T1..T5 `Repeat: Every: 0 Hour(s), 1 Minute(s)` and execution limit `00:00:59`.
  - Gate evaluator `Repeat: Every: 0 Hour(s), 5 Minute(s)` and execution limit `00:04:00`.

## Result

- Installed/verified target tasks per parent comment requirements.
- No T6 task created or touched.
