# News-calendar timestamp defect: Q09/Q10/Q14 blast radius

Generated UTC: 2026-09-04T23:20:49.068409+00:00

## Result

The read-only census classified 171 latest completed phase/pair rows across 125 distinct EA/symbol pairs: `{"EXPOSED": 63, "INERT": 108}`.

`INERT` means the USD event is not applicable, the effective news mode is off, or the daily/slower entry grid cannot intersect either ±30 minute slot. `EXPOSED` means a USD-applicable intraday EA has an active news filter and can enter in at least one slot. Ambiguous source/mode/timeframe cases remain `UNKNOWN`.

## Counts by phase, verdict, and class

| phase | verdict | class | count |
|---|---|---|---:|
| Q09 | FAIL | EXPOSED | 9 |
| Q09 | FAIL | INERT | 5 |
| Q09 | INFRA_FAIL | INERT | 1 |
| Q09 | PASS | EXPOSED | 39 |
| Q09 | PASS | INERT | 67 |
| Q10 | FAIL | EXPOSED | 1 |
| Q10 | PASS | EXPOSED | 11 |
| Q10 | PASS | INERT | 23 |
| Q14 | KEEP_INCUMBENT | EXPOSED | 1 |
| Q14 | KEEP_INCUMBENT | INERT | 7 |
| Q14 | OPT_ELIGIBLE | EXPOSED | 2 |
| Q14 | OPT_ELIGIBLE | INERT | 2 |
| Q14 | OPT_REJECTED | INERT | 3 |

## Q14 KEEP_INCUMBENT rows classified EXPOSED

Across all 9 historical KEEP_INCUMBENT rows (including repeated decisions for the same pair), classifications are `{"EXPOSED": 1, "INERT": 8}`.

- `b5e18759-1377-5af7-9634-9f66bd293d0c` — QM5_10706 / GBPUSD.DWX (active_news_filter_on_H1_intraday_entry_grid)

## Q11 PASS pairs classified EXPOSED

- QM5_10700 / XAUUSD.DWX
- QM5_10706 / GBPUSD.DWX
- QM5_11294 / XAUUSD.DWX
- QM5_11660 / NDX.DWX
- QM5_13013 / NDX.DWX
- QM5_13213 / USDJPY.DWX
- QM5_21501 / USDJPY.DWX

## Entry-timestamp spot check

Five EXPOSED and five INERT classifications were requested. The available native reports yielded 10 checks: 10 agreement / 0 disagreement. Counts use unique entry timestamps converted from Darwinex broker wall time to UTC with `qm.dst_rule.us.v1`; true windows are ±30 minutes around 12:30/13:30Z, and displaced windows are Thursday ±30 minutes around 19:30/20:30Z.

See `spot_checks.csv` for counts and samples. A static EXPOSED classification means the EA *can* enter in the interval; a zero empirical count in one finite report is retained as a disagreement rather than silently reclassifying the EA.

## Method and limits

- SQLite was opened with `mode=ro` and `PRAGMA query_only=ON`.
- For each `(phase, ea_id, symbol)`, the latest completed non-null verdict row was selected.
- Exact set/MQ5/EX5 paths, current hashes, stored evidence hashes, evidence paths, and report paths are in `blast_radius.csv` and `blast_radius.json`.
- `q14_keep_incumbent.*` preserves all nine historical KEEP_INCUMBENT rows; `q11_pass_classifications.*` gives one classification for each of the 31 Q11 PASS pairs.
- USD applicability follows `QM_NewsIndexCurrencies` plus base/quote currency legs. NDX/SP500/WS30 aliases therefore count as USD; GDAXI does not.
- The analysis is report-only. It does not alter verdicts or claim that an affected verdict would reverse under corrected timestamps.

No calendar, gate, verdict, database, terminal, T_Live, or AutoTrading state was changed.
