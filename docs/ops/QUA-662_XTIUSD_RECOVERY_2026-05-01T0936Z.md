# QUA-662 XTIUSD recovery note (2026-05-01T09:36Z)

## What changed

- Initial XTIUSD baseline run failed on T2 with `REPORT_MISSING` + size-0 report files.
- Controlled rerun on T1 (same EA/symbol/year/model/setfile contract) passed.

Evidence:
- PASS summary: `D:/QM/reports/pipeline/QM5_1003/P2/QM5_1003/20260501_092824/summary.json`
- PASS run evidence: `D:/QM/reports/framework/22/20260501_092824_QM5_1003_run_smoke.md`

## Interpretation

- Failure mode is terminal/path/runtime-local (T2 run condition), not strategy weakness on XTIUSD.
- V5 NO_REPORT disambiguation rule applied before any EA-quality claim.

## Dispatch state update

- Canonical dispatch lifecycle replayed with non-pinned dedup key:
  - `QM5_1003|v1|XTIUSD.DWX|P2|H1-2024-r1`
  - `scheduled -> released`
- Matrix row for `XTIUSD.DWX` now carries PASS verdict + PASS evidence.

## report.csv refresh

- `D:/QM/reports/pipeline/QM5_1003/P2/report.csv` regenerated from `dispatch_state` matrix.
- Current row set: EURUSD, GBPUSD, USDJPY, XAUUSD, XTIUSD (all PASS).

## Next action

- Continue expanding P2 cohort toward broader DWX matrix while monitoring terminal-local anomalies (especially T2) for repeat NO_REPORT patterns.
