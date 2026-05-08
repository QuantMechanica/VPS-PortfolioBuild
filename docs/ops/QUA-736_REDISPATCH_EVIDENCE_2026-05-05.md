# QUA-736 Re-Dispatch Evidence (2026-05-05)

## Liveness instruction executed

Re-ran clean P2 matrix `start` for `QM5_1003_v1_P2` using patched resolver path.

## Command

```powershell
python framework/scripts/resolve_backtest_target.py `
  --job-json C:\QM\repo\.scratch\qua662_p2_matrix_dispatch_2026-05-05.json `
  --state-json D:\QM\Reports\pipeline\dispatch_state.json `
  --event start --prune-completed `
  --report-csv D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174219\report.csv
```

## Dispatch result

- run dir: `D:\QM\reports\pipeline\QM5_1003\P2_clean_20260505_174219`
- `scheduled=0`
- `duplicate=15`
- `no_capacity=21`

## Critical state verification (post-run)

`D:\QM\Reports\pipeline\dispatch_state.json` bucket `QM5_1003_v1_P2`:

- `rows=36`
- `none_verdict_rows=36`
- `pass_rows=0`
- `phase_verdict=None`
- phantom symbols absent: `GDAXI.DWX=False`, `NDX.DWX=False`
- canonical symbols present: `GDAXIm.DWX=True`, `NDXm.DWX=True`

## Additional fix applied during this heartbeat

Found and fixed persistence gap in resolver:
- `initialize_matrix_bucket_for_symbols(...)` mutated in-memory state but was not saved when `scheduled=0`.
- Set `should_save=True` immediately after matrix initialization in `framework/scripts/resolve_backtest_target.py` so reset persists on duplicate/no-capacity waves.

## Verification

```powershell
python -m unittest framework.scripts.tests.test_pipeline_dispatcher
```

- Result: `Ran 25 tests ... OK`

## Next action

Capacity is full (`T1..T5` all at 3/3). Process completion/release events for the 15 in-flight dedup rows, then re-run matrix `start` to schedule the remaining 21 rows.
