# QUA-747 Rerun Execution Snapshot (2026-05-06)

## Commands executed this heartbeat

1. 1003 six-symbol recovery rerun:
- `python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols AUDCAD.DWX,EURAUD.DWX,GBPAUD.DWX,NDXm.DWX,NZDCAD.DWX,USDCHF.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120 --resume`
- Outcome: 6/6 `FAIL` with `run_smoke_fail:TIMEOUT;METATESTER_HUNG;INCOMPLETE_RUNS` after one retry each.

2. 1004 probe rerun:
- `python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols AUDCAD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`
- Outcome: `FAIL` `run_smoke_fail:MIN_TRADES_NOT_MET` (non-modal).

3. 1009 probe rerun (EA label `QM5_SRC04_S03`, ea_id 1009):
- `python framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --symbols AUDCAD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`
- Outcome: retry #1 `REPORT_MISSING;INCOMPLETE_RUNS`, attempt #2 `MIN_TRADES_NOT_MET`.

4. 1017 probe rerun:
- `python framework/scripts/p2_baseline.py --ea QM5_1017 --symbols AUDCAD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`
- Outcome: `FAIL` `run_smoke_fail:MIN_TRADES_NOT_MET` (non-modal).

## Recomputed NO_REPORT-class snapshot

Flags counted as modal:
- `REPORT_MISSING`
- `METATESTER_HUNG`
- `INCOMPLETE_RUNS`

Symbol-latest snapshot by cohort report.csv:
- `QM5_1003`: symbols=37, modal_symbols=0, modal_rate=0.00%
- `QM5_1004`: symbols=5, modal_symbols=3, modal_rate=60.00%
- `QM5_1009` (`QM5_SRC04_S03` path): symbols=6, modal_symbols=0, modal_rate=0.00%
- `QM5_1017`: symbols=4, modal_symbols=0, modal_rate=0.00%

Cohort aggregate (latest row per symbol currently available):
- symbols=52
- modal=3
- modal_rate=5.77%

## Gate status

Acceptance criterion #4 (`< 5%` modal rate across full cohort) is **still not met** in current available evidence.

## Notes

- This heartbeat executed concrete reruns and produced fresh rows.
- Full 108-symbol closure cohort is still incomplete in current files; additional Pipeline-Op reruns are required for final gate decision.