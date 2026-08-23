# Backfill Plan — Pipeline Rebaseline

Generated: `2026-08-23T10:54:36+00:00`
State DB: `D:/QM/strategy_farm/state/farm_state.sqlite` (**read-only mode=ro**)
Input census: `D:/QM/reports/rebaseline/census_2026-08-23.csv`
Gate contract: `v3` (active runtime; v4 remains read-inert)
Mode: **dry-run; no enqueue was executed**

## Summary

- Rows: **14607** (14513 pair, 94 compile classifications)
- Enqueue-ready after binding/cap checks: **1471**
- Estimated factory time: **34834.780 h** (sum of target-phase medians; work-item `updated_at - created_at`)

| action | rows |
|---|---:|
| RERUN_INFRA | 1060 |
| FILL_MISSING | 5019 |
| REBIND_STALE | 84 |
| SKIP_REUSABLE | 0 |
| STOP_ECONOMIC_FAIL | 7439 |
| STOP_NOT_APPLICABLE | 12 |
| UNKNOWN | 993 |

## Phase median durations

| gate | median hours |
|---|---:|
| Q02 | 6.5308 |
| Q03 | 5.5727 |
| Q04 | 3.0550 |
| Q05 | 0.6056 |
| Q06 | 0.3203 |
| Q07 | 1.3092 |
| Q08 | 1.2914 |
| Q09 | 0.3192 |
| Q10 | 0.0000 |
| Q14 | 0.0000 |
| Q15 | 0.0000 |

## Top 50 — frontier-first / earliest-gap-first

| rank | EA | symbol | frontier | next gate | action | hours | enqueue | reason |
|---:|---|---|---|---|---|---:|---|---|
| 1 | QM5_10706 | GBPUSD.DWX | Q10 | Q14 | UNKNOWN | 0.000 | false | unclassified_frontier:OTHER |
| 2 | QM5_11421 | EURUSD.DWX | Q10 | Q14 | FILL_MISSING | 0.000 | false | earliest_prerequisite_has_no_evidence;runtime_phase_not_supported_by_farmctl_enqueue_backtest;incomplete_hash_window_or_parent_binding |
| 3 | QM5_11422 | USDCAD.DWX | Q10 | Q14 | UNKNOWN | 0.000 | false | unclassified_frontier:OTHER |
| 4 | QM5_10142 | SP500.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | false | invalid_evidence_at_q09_news;incomplete_hash_window_or_parent_binding |
| 5 | QM5_10146 | AUDUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 6 | QM5_10123 | XAUUSD.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | false | invalid_evidence_at_q09_news;incomplete_hash_window_or_parent_binding |
| 7 | QM5_11129 | SP500.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 8 | QM5_10145 | XAUUSD.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | false | invalid_evidence_at_q09_news;incomplete_hash_window_or_parent_binding |
| 9 | QM5_10128 | XAUUSD.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | false | invalid_evidence_at_q09_news;incomplete_hash_window_or_parent_binding |
| 10 | QM5_11288 | USDJPY.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 11 | QM5_10183 | XAUUSD.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | false | invalid_evidence_at_q09_news;incomplete_hash_window_or_parent_binding |
| 12 | QM5_12823 | USDJPY.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 13 | QM5_12623 | XAUUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 14 | QM5_13036 | GDAXI.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | true | invalid_evidence_at_q09_news |
| 15 | QM5_13128 | NDX.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 16 | QM5_13301 | GDAXI.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | true | invalid_evidence_at_q09_news |
| 17 | QM5_20048 | XTIUSD.DWX | Q08 | Q09 | RERUN_INFRA | 0.319 | true | invalid_evidence_at_q09_news |
| 18 | QM5_12708 | XAUUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 19 | QM5_20266 | XTIUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 20 | QM5_9641 | WS30.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 21 | QM5_12849 | XTIUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 22 | QM5_12855 | XTIUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 23 | QM5_13054 | XTIUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 24 | QM5_11294 | GDAXI.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 25 | QM5_21505 | XAGUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 26 | QM5_11881 | GBPUSD.DWX | Q08 | Q09 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 27 | QM5_10038 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 28 | QM5_10069 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 29 | QM5_10094 | GDAXI.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 30 | QM5_10114 | SP500.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 31 | QM5_10115 | GDAXI.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 32 | QM5_10116 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 33 | QM5_10127 | AUDCAD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 34 | QM5_10127 | AUDUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 35 | QM5_10150 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 36 | QM5_10163 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 37 | QM5_10170 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 38 | QM5_10196 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 39 | QM5_10197 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 40 | QM5_1551 | USDJPY.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 41 | QM5_10135 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 42 | QM5_10135 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 43 | QM5_10146 | XTIUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 44 | QM5_10148 | EURNZD.DWX | Q07 | Q08 | RERUN_INFRA | 1.291 | false | non_economic_failure_at_earliest_prerequisite;incomplete_hash_window_or_parent_binding |
| 45 | QM5_10260 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 46 | QM5_10375 | SP500.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 47 | QM5_10403 | GDAXI.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 48 | QM5_10403 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 49 | QM5_12112 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 50 | QM5_10428 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |

## Safety and interpretation

The rank key is contiguous frontier descending, remaining gates ascending, then oldest pair first. Only the earliest gap is represented for a pair. Economic FAIL and not-applicable rows are terminal. Reruns use `--append-only-rerun-of`; exact economic identities are globally deduplicated. Rows lacking build/setfile/window/parent-evidence bindings, rows behind the active symbol cap, and runtime phases unsupported by `farmctl enqueue-backtest` are visible but not apply-eligible.

COMPILE_EA failures are a separate repair ticket. They are `RERUN_INFRA` only when a reachable compile log contains the documented missing `Trade/Trade.mqh` or `Object.mqh` signature; all other COMPILE_FAIL rows are `UNKNOWN` and never become backtest commands.

Machine artifacts: `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv` and `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.json`.
