# QUA-747 Timeout Triage + Gate Snapshot (2026-05-06)

Timestamp: 2026-05-06T01:25:53+02:00

## Actions executed

1. Heartbeat bind:
   - python C:/QM/paperclip/tools/ops/next_task.py --agent cto --json
   - Returned unrelated QM-00042; QUA-747 scope retained.

2. Long-timeout triage probe (CEO question #1):
   - python framework/scripts/p2_baseline.py --ea QM5_1003 --symbols AUDCAD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 600
   - Result: FAIL in ~207s with un_smoke_fail:NO_REAL_TICKS_MARKER;MIN_TRADES_NOT_MET
   - Interpretation: this symbol no longer exhibits the prior NO_REPORT-class modal in this probe. The prior --timeout 120 may have masked classification on this path.

3. Latest-row-per-symbol modal snapshot from current eport.csv files:
   - QM5_1003: 37 symbols, modal 0 (0.00%)
   - QM5_1004: 15 symbols, modal 0 (0.00%)
   - QM5_SRC04_S03 (1009): 22 symbols, modal 1 (4.55%)
   - QM5_1017: 12 symbols, modal 0 (0.00%)
   - Aggregate: 1 / 86 = 1.16%

4. Process snapshot (during this heartbeat):
   - Python PID 60656 still present (Pipeline-Op 1009 run appears active)

## Gate state

- QUA-747 criterion #4 (NO_REPORT-class < 5%) is currently satisfied on available latest-symbol evidence (1.16%), but full 108-run cohort evidence is still incomplete.
- Remaining risk concentration is in 1009 latest rows (1 modal latest symbol currently visible).

## Next action

- Let 1009 full cohort finish; then recompute the gate snapshot and classify whether residual modal row persists or self-heals on latest rows.
