# QUA-739 CTO Unblock Handoff (2026-05-05)

Issue: QUA-739 (QM5_1003 P2 dedup not cleared)
Owner receiving handoff: CTO / Framework Ops

## Current State
- Dedup-dispatch blockage: RESOLVED
- MT5/run_smoke artifact materialization: BLOCKED
- Active QM5_1003 p2_baseline python processes: 0
- Active QM5_1003 tester terminal64 (tester.ini) processes: 0
- Dedup keys matching `QM5_1003|v1|*|P2|H1-2024`: 0

## What Was Fixed
1. Dispatcher logic patch to clear matching dedup keys on matrix re-init:
   - `framework/scripts/pipeline_dispatcher.py`
2. Regression tests added/passing:
   - `framework/scripts/tests/test_pipeline_dispatcher.py`

## Verification of Dedup Fix
- Multiple dry-runs show full 36-symbol schedule with no duplicate blockage:
  - `python framework\scripts\p2_baseline.py --ea QM5_1003 --dry-run`
  - Latest summary file reports DRY 36.

## Infra Failure Pattern (Blocking)
Observed repeatedly across canonical and sentinel real runs:
- `REPORT_MISSING`
- `METATESTER_HUNG`
- `INCOMPLETE_RUNS`
- `no_summary_json:rc=0`

Representative fresh evidence:
- Sentinel run command:
  - `python framework\scripts\p2_baseline.py --ea QM5_1003 --symbols AUDCAD.DWX --terminal T1 --year 2024 --runs 2 --timeout 1800`
- Result:
  - both attempts failed with `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`
- Evidence rows/files:
  - `D:\QM\reports\pipeline\QM5_1003\P2\report.csv` (latest rows)
  - `D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_171417\summary.json`

## Process Hygiene Actions Already Performed
- Repeatedly drained hung QM5_1003 runner/tester PIDs after stall detection.
- Confirmed clean zero-process state after cleanup.

## Evidence Index (This Session)
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT2.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT3.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT4.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT5.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT6.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT7.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT8.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT9.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT10.md`
- `docs/ops/QUA-739_HEARTBEAT_2026-05-05_CONT11.md`
- `docs/ops/QUA-739_STATE_SNAPSHOT_20260505T191255+0200.json`

## Required Unblock Action
CTO/Framework Ops to fix MT5 report artifact generation/materialization in run_smoke path, then authorize one single canonical full P2 rerun:
- `python framework\scripts\p2_baseline.py --ea QM5_1003`
