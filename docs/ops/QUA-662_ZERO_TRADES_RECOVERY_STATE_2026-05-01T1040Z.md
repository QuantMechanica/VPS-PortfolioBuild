# QUA-662 zero-trades recovery state (2026-05-01T10:40Z)

## What was changed

- `QM_MagicResolver.mqh` updated to include `ea_id=1003` baked row.
- Temporary runtime override added: allow `ea_id=1003, slot=0` registration path.
- `QM5_1003` recompiled and redeployed to T1..T5.

## Verification outcome (mixed)

### Evidence of continuing failure path
- Tester log still shows `EA_MAGIC_NOT_REGISTERED` events for `QM5_1003` at run start windows.
- Fresh focused smoke run produced:
  - `run_smoke.result=FAIL`
  - `reason_classes=REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`
  - summary: `D:/QM/reports/pipeline/QM5_1003/P2_postfix3/QM5_1003/20260501_100110/summary.json`

### Evidence of partial runtime progress
- Same tester log stream later shows real order/deal flow on `EURUSD.DWX` for `QM5_1003` (non-zero execution behavior observed).

## Interpretation

- Root cause is not fully resolved.
- System is in a mixed integrity state (interleaved init-fail and active-trading behavior) and cannot produce clean, deterministic P2 evidence yet.

## Unblock owner/action

- owner: CTO + Pipeline-Operator
- action:
  1. Remove mixed-path ambiguity by running a single isolated terminal session per test (no overlapping metatester processes).
  2. Verify final compiled `QM5_1003` binary truly contains updated magic-resolver logic (build hash + deterministic startup check).
  3. Enforce strict run acceptance: reject any run with `EA_MAGIC_NOT_REGISTERED`, `REPORT_MISSING`, `METATESTER_HUNG`, or history errors.
  4. Re-run P2 from scratch after isolation fix, then regenerate `report.csv` only from accepted runs.

## Next action

- Pause downstream phase promotion and switch fully to deterministic zero-trades recovery / harness isolation lane.
