# QUA-1155: QM5_1014 P2 REPORT_MISSING triage (2026-05-09)

## Snapshot

- Source file: `D:/QM/reports/pipeline/QM5_1014/P2/report.csv`
- Rows: 20
- Verdicts: `FAIL=11`, `INVALID=9`, `PASS=0`
- Reason counts:
  - `no_summary_json:rc=1` -> 9
  - `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS` -> 5
  - `run_smoke_fail:REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS` -> 2
  - `run_smoke_fail:MIN_TRADES_NOT_MET` -> 4

`REPORT_MISSING` appears in 7/20 rows (35%). On the FAIL-only subset, it is 7/11 (63.6%). This supports infra/toolchain instability in addition to strategy-level MIN_TRADES cases.

## Root-cause gap found

In `framework/scripts/run_smoke.ps1`, when `report.htm` is missing the script marked `REPORT_MISSING` but dropped tester-log linkage (`tester_log_path = $null`). That removed the primary artifact needed to confirm whether the run was a metatester hang vs other terminal failure mode.

## Change shipped

- Updated `framework/scripts/run_smoke.ps1` to always capture and copy the latest tester log immediately after each tester run returns, before checking `report.htm`.
- `REPORT_MISSING` rows now preserve `tester_log_path`, enabling direct forensic triage on each failed run directory.

## Next verification action

Run a pinned-terminal probe on QM5_1014 and inspect saved tester logs in any `REPORT_MISSING` row:

`python framework/scripts/p2_baseline.py --ea QM5_1014 --period M15 --year 2024 --symbols EURUSD.DWX,USDJPY.DWX --terminal T3 --runs 2 --timeout 1800`

Then validate the produced summary rows include non-null `tester_log_path` for `REPORT_MISSING` cases and classify hang signature from log tail.
