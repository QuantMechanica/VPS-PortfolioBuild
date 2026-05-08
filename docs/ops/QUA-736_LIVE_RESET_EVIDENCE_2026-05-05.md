# QUA-736 Live Dispatch State Reset Evidence (2026-05-05)

## Scope

Reset contaminated phase bucket in live dispatch state:
- file: `D:\QM\Reports\pipeline\dispatch_state.json`
- bucket: `QM5_1003_v1_P2`

## Pre-Reset Confirmation

- `rows=36`
- `pass_rows=36`
- `phase_verdict=PASS`
- phantom symbols present in PASS rows: `GDAXI.DWX`, `NDX.DWX`

## Action Taken

1. Backup created:
   - `D:\QM\Reports\pipeline\dispatch_state.json.bak_qua736_reset_20260505T154058Z`
2. Bucket reset fields:
   - `matrix=[]`
   - `phase_verdict=null`
   - `next_strategy_unblocked=null`
3. Audit marker appended in state file:
   - `ops_resets[]` with `issue=QUA-736`, `bucket=QM5_1003_v1_P2`, UTC timestamp.

## Post-Reset Verification

- `bucket_exists=True`
- `rows=0`
- `pass_rows=0`
- `phase_verdict=None`
- `next_strategy_unblocked=None`
- `GDAXI.DWX` present: `False`
- `NDX.DWX` present: `False`

## Next Action

Run clean P2 matrix dispatch start for `QM5_1003_v1_P2` (with the patched initializer path) so the bucket is repopulated from current canonical symbols only, then evaluate verdict from fresh rows.
