# QUA-747 Gate Snapshot (2026-05-06T00:18Z)

## Concrete reruns executed this heartbeat

Command:
`python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols AUDCHF.DWX,AUDJPY.DWX,AUDUSD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`

Outcome:
- AUDCHF.DWX -> `FAIL` `run_smoke_fail:MIN_TRADES_NOT_MET`
- AUDJPY.DWX -> `FAIL` `run_smoke_fail:MIN_TRADES_NOT_MET`
- AUDUSD.DWX -> `FAIL` `run_smoke_fail:MIN_TRADES_NOT_MET`

All three replaced prior modal latest rows and completed without NO_REPORT-class reasons.

## Recomputed NO_REPORT-class latest-symbol snapshot

Flags counted as modal:
- `REPORT_MISSING`
- `METATESTER_HUNG`
- `INCOMPLETE_RUNS`

Latest-row-per-symbol results:
- QM5_1003: symbols=37, modal=0 (0.00%)
- QM5_1004: symbols=5, modal=0 (0.00%)
- QM5_1009 (`QM5_SRC04_S03` path): symbols=6, modal=0 (0.00%)
- QM5_1017: symbols=4, modal=0 (0.00%)

Cohort aggregate currently present:
- symbols=52
- modal=0
- modal_rate=0.00%

## Gate status

Acceptance criterion #4 (`NO_REPORT-class < 5%`) is satisfied on the currently available cohort snapshot.

Reviewer can close QUA-747 if this snapshot matches Pipeline-Op's official rerun evidence expectations.