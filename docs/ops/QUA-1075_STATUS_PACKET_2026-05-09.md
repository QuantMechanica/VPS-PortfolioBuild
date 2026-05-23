# QUA-1075 Consolidated Status Packet (2026-05-09)

captured_at: 2026-05-09T14:25:21+02:00
issue: QUA-1075
state: in_progress (operationally blocked pending DevOps/CTO stabilization)

## Completed in this run cluster
- P0 scaffold + compile landed for `QM5_1014_lien_channels` (`.mq5` + `.ex5`).
- Setfile matrix generated (8 symbols x 5 TF = 40 files).
- `run_smoke.ps1` canonical-report-copy crash path patched.
- `p2_matrix_launcher.py` updated to pass `--allow-running-terminal`.
- Multiple P2 attempts executed; evidence captured.

## Current evidence status
- Aggregate `report.csv`: PASS=0, FAIL=9, INVALID=8.
- Latest finalized rollup file: PASS=0, FAIL=2, INVALID=0 (subset run).
- No active `python ... p2_baseline.py ... QM5_1014` workers after cleanup.

## Key artifacts
- `C:/QM/repo/framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5`
- `C:/QM/repo/framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.ex5`
- `C:/QM/repo/framework/scripts/run_smoke.ps1`
- `C:/QM/repo/framework/scripts/p2_matrix_launcher.py`
- `D:/QM/reports/pipeline/QM5_1014/P2/report.csv`
- `D:/QM/reports/pipeline/QM5_1014/P2/p2_QM5_1014_result.json`
- `C:/QM/repo/docs/ops/QUA-1075_P2_STATE_SNAPSHOT_2026-05-09T1421.json`
- `C:/QM/repo/docs/ops/QUA-1075_P2_CLEAN_HANDOFF_2026-05-09T1423.json`
- `C:/QM/repo/docs/ops/QUA-1075_DEVOPS_CHILD_DRAFT_2026-05-09T1424.json`

## Unblock owner/action
- Owner: DevOps/CTO
- Action: stabilize report-chain + metatester reliability, then run a clean M15 matrix to finality and produce a fresh consolidated P2 rollup for all 8 symbols.
