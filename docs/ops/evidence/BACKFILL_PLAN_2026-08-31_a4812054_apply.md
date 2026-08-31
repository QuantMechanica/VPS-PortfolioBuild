# Backfill Plan — Pipeline Rebaseline

Generated: `2026-08-31T04:24:50+00:00`
State DB: `D:/QM/strategy_farm/state/farm_state.sqlite` (**read-only mode=ro**)
Input census: `recomputed:D:\QM\strategy_farm\state\farm_state.sqlite`
Gate contract: `v4` (active runtime; v4 remains read-inert)
Mode: **dry-run; no enqueue was executed**

## Summary

- Rows: **14884** (14695 pair, 189 compile classifications)
- Enqueue-ready after binding/cap checks: **860**
- Estimated factory time (full reparable backfill, bindings pending): **34888.507 h** (sum of target-phase medians over every enqueue-action row; work-item `updated_at - created_at`)
- Estimated factory time (enqueue-ready now): **5050.232 h** (enqueue-eligible rows only)

| action | rows |
|---|---:|
| RERUN_INFRA | 1080 |
| FILL_MISSING | 4946 |
| REBIND_STALE | 95 |
| SKIP_REUSABLE | 0 |
| STOP_ECONOMIC_FAIL | 7509 |
| STOP_DETERMINISTIC_INFRA | 210 |
| STOP_NOT_APPLICABLE | 0 |
| UNKNOWN | 1044 |

## Phase median durations

| gate | median hours |
|---|---:|
| Q02 | 6.5261 |
| Q03 | 5.4874 |
| Q04 | 2.9907 |
| Q05 | 0.6265 |
| Q06 | 0.3261 |
| Q07 | 1.5631 |
| Q08 | 1.4200 |
| Q09 | 83.6871 |
| Q10 | 28.3985 |
| Q11 | 0.3358 |
| Q12 | 6.8734 |
| Q13 | 0.0047 |
| Q14 | 0.0000 |

## Top 50 — frontier-first / earliest-gap-first

| rank | EA | symbol | frontier | next gate | action | hours | enqueue | reason |
|---:|---|---|---|---|---|---:|---|---|
| 1 | QM5_10142 | SP500.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 2 | QM5_10146 | AUDUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 3 | QM5_10513 | XAUUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 4 | QM5_10123 | XAUUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 5 | QM5_10706 | GBPUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | true | stale_or_contract_gap_at_q09_news |
| 6 | QM5_11129 | SP500.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 7 | QM5_10145 | XAUUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 8 | QM5_10128 | XAUUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 9 | QM5_11421 | EURUSD.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 10 | QM5_11288 | USDJPY.DWX | Q09 | Q10 | RERUN_INFRA | 28.398 | true | infra_failure_at_q09_news |
| 11 | QM5_10183 | XAUUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 12 | QM5_12623 | XAUUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 13 | QM5_13013 | NDX.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 14 | QM5_13036 | GDAXI.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 15 | QM5_13128 | NDX.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 16 | QM5_11422 | USDCAD.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 17 | QM5_20048 | XTIUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | true | stale_or_contract_gap_at_q09_news |
| 18 | QM5_12708 | XAUUSD.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_manual_review_required |
| 19 | QM5_20188 | USDJPY.DWX | Q09 | Q10 | FILL_MISSING | 28.398 | false | q09_news_prerequisite_missing;incomplete_hash_window_or_parent_binding |
| 20 | QM5_20266 | XTIUSD.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 21 | QM5_9641 | WS30.DWX | Q09 | Q10 | RERUN_INFRA | 28.398 | true | infra_failure_at_q09_news |
| 22 | QM5_12849 | XTIUSD.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 23 | QM5_12855 | XTIUSD.DWX | Q09 | Q10 | UNKNOWN | 0.000 | false | q09_news_prerequisite_in_flight |
| 24 | QM5_13054 | XTIUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 25 | QM5_21501 | USDJPY.DWX | Q09 | Q10 | FILL_MISSING | 28.398 | false | q09_news_prerequisite_missing;incomplete_hash_window_or_parent_binding |
| 26 | QM5_11294 | GDAXI.DWX | Q09 | Q10 | RERUN_INFRA | 28.398 | true | infra_failure_at_q09_news |
| 27 | QM5_21505 | XAGUSD.DWX | Q09 | Q10 | RERUN_INFRA | 28.398 | true | infra_failure_at_q09_news |
| 28 | QM5_11881 | GBPUSD.DWX | Q09 | Q10 | REBIND_STALE | 28.398 | false | stale_or_contract_gap_at_q09_news;incomplete_hash_window_or_parent_binding |
| 29 | QM5_11881 | SP500.DWX | Q09 | Q10 | FILL_MISSING | 28.398 | true | q09_news_prerequisite_missing |
| 30 | QM5_41161 | GBPUSD.DWX | Q09 | Q10 | FILL_MISSING | 28.398 | true | q09_news_prerequisite_missing |
| 31 | QM5_12823 | USDJPY.DWX | Q08 | Q09 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 32 | QM5_13301 | GDAXI.DWX | Q08 | Q09 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 33 | QM5_10038 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 34 | QM5_10069 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 35 | QM5_10094 | GDAXI.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 36 | QM5_10114 | SP500.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 37 | QM5_10115 | GDAXI.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 38 | QM5_10116 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 39 | QM5_10127 | AUDCAD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 40 | QM5_10127 | AUDUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 41 | QM5_10150 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 42 | QM5_10163 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 43 | QM5_10170 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 44 | QM5_10196 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 45 | QM5_10197 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 46 | QM5_1551 | USDJPY.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 47 | QM5_10135 | NDX.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 48 | QM5_10135 | XAUUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 49 | QM5_10146 | XTIUSD.DWX | Q07 | Q08 | STOP_ECONOMIC_FAIL | 0.000 | false | terminal_economic_fail_at_frontier |
| 50 | QM5_10148 | EURNZD.DWX | Q07 | Q08 | RERUN_INFRA | 1.420 | false | non_economic_failure_at_earliest_prerequisite;incomplete_hash_window_or_parent_binding |

## Safety and interpretation

The rank key is contiguous frontier descending, remaining gates ascending, then oldest pair first. Only the earliest gap is represented for a pair. Economic FAIL and not-applicable rows are terminal. Reruns use `--append-only-rerun-of`; exact economic identities are globally deduplicated. Rows lacking build/setfile/window/parent-evidence bindings, rows behind the active symbol cap, and runtime phases unsupported by `farmctl enqueue-backtest` are visible but not apply-eligible.

Deterministic `ONINIT_FAILED` / INPUTSVALID framework pins and EA-defect compile classes are `STOP_DETERMINISTIC_INFRA`: they require a code fix and never become rerun commands. Other COMPILE_EA failures are `RERUN_INFRA` only when a reachable compile log contains the documented missing `Trade/Trade.mqh` or `Object.mqh` signature; unclassified compile failures remain `UNKNOWN`.

Machine artifacts: `D:/QM/reports/rebaseline/a4812054_apply/backfill_plan_2026-08-31_a4812054_apply.csv` and `D:/QM/reports/rebaseline/a4812054_apply/backfill_plan_2026-08-31_a4812054_apply.json`.
