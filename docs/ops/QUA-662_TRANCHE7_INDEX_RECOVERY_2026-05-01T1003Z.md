# QUA-662 tranche-7 index recovery (2026-05-01T10:03Z)

## Recovery action

Controlled reruns executed on `T1` for prior NO_REPORT index failures:
- `GDAXI.DWX`
- `JPN225.DWX`

Both reruns: `PASS`.

## PASS evidence

- `GDAXI.DWX`: `D:/QM/reports/pipeline/QM5_1003/P2/QM5_1003/20260501_094358/summary.json`
- `JPN225.DWX`: `D:/QM/reports/pipeline/QM5_1003/P2/QM5_1003/20260501_094415/summary.json`

## Dispatch + matrix update

For each symbol, canonical non-pinned lifecycle applied:
- `scheduled -> released`

Matrix rows for `GDAXI.DWX` and `JPN225.DWX` now carry `PASS` verdicts with the rerun evidence paths.

## report.csv refresh

- `D:/QM/reports/pipeline/QM5_1003/P2/report.csv` regenerated from `dispatch_state` matrix.
- Current row count remains `34` unique symbols.
- P2 matrix verdict remains `PASS`.

## Next action

Proceed to the remaining uncovered DWX symbols (if any) or promote from P2 to next gate per pipeline sequence.
