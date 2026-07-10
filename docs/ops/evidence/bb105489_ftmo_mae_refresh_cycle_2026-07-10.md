# FTMO Round25 MAE refresh post-OOM cycle — 2026-07-10

Task: `bb105489-2a1f-4af4-8cff-1ada6e43394b`

Supersedes: `20cfbf8d-0ce9-4fa7-acc8-9d45ce319df4`

Cycle observation cutoff: `2026-07-10T10:14:24Z`

## Verdict

**INCOMPLETE — REVIEW / CONTROLLED RECYCLE REQUIRED.** The exact stream-schema
inventory improved from `4/12` to `7/12`, but the routed acceptance condition
(`12/12` fresh streams plus the final CE(S)T Phase-1 artifact) is not met.

No target backtest was launched in this cycle. All seven enabled factory
terminals were continuously occupied by unrelated Q02 work, and a second live
Codex process was operating in the canonical checkout while three target
streams changed. Starting another target run would have risked duplicate work
or a report/metatester collision. No active T1–T10 backtest was interrupted.

The final `ftmo_phase1_mae.py` simulator was deliberately not run: a partial
book is non-authoritative under the routed task contract.

## Exact 12-sleeve stream inventory

Only `TRADE_CLOSED` rows were counted. `FRESH` requires every counted row to
contain numeric `entry_time` and `mae_acct`.

| EA | Expected symbol | Closed rows | Rows with both fields | State | Stream last-write UTC |
|---|---|---:|---:|---|---|
| `QM5_10163` | `NDX.DWX` | 168 | 168 | FRESH | `2026-07-08T00:06:40Z` |
| `QM5_10286` | `XTIUSD.DWX` | 50 | 0 | STALE | `2026-06-30T04:52:18Z` |
| `QM5_10440` | `NDX.DWX` | 768 | 768 | FRESH | `2026-07-07T21:34:33Z` |
| `QM5_10692` | `NDX.DWX` | 441 | 0 | STALE | `2026-07-03T22:37:11Z` |
| `QM5_10700` | `XAUUSD.DWX` | 373 | 373 | FRESH | `2026-07-10T09:47:32Z` |
| `QM5_10847` | `GBPUSD.DWX` | 802 | 802 | FRESH | `2026-07-10T09:14:20Z` |
| `QM5_10848` | `XAUUSD.DWX` | 1,213 | 0 | STALE | `2026-07-03T11:21:04Z` |
| `QM5_10911` | `GDAXI.DWX` | 330 | 330 | FRESH | `2026-07-10T09:59:22Z` |
| `QM5_11476` | `USDJPY.DWX` | 775 | 0 | STALE | `2026-06-29T14:17:54Z` |
| `QM5_12475` | `NDX.DWX` | 611 | 0 | STALE | `2026-06-29T17:13:50Z` |
| `QM5_12958` | `XAUUSD.DWX` | 71 | 71 | FRESH | `2026-07-04T17:49:55Z` |
| `QM5_12990` | `GBPUSD.DWX` | 34 | 34 | FRESH | `2026-07-04T17:35:33Z` |

The three newly fresh target streams (`10700`, `10847`, `10911`) appeared
after task routing. `10700` has a pre-existing 373-trade full-history report at
`D:/QM/reports/ftmo_mae_refresh_20260710/QM5_10700/20260710_071140/raw/run_02/report.htm`,
but its later stream write was not linked to a new same-run report during this
cycle. Same-run report paths for `10847` and `10911` were not located. These
rows therefore prove schema progress, not the task's complete per-run
report-to-stream reconciliation contract.

## Build and guardrail verification

- Bounded/incremental Q08 emission is present through the `7f39b386f` trigger
  and `381acb4f0` flush implementation; `0a1c7fee4` rebuilt the final two
  target binaries.
- `validate_build_guardrails.py` passed all eight target EA directories with
  `max_news_stale_hours=336` and zero findings.
- All exact target backtest setfiles inspected use `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- Focused CE(S)T mechanics tests passed: `4 passed` in
  `tools/strategy_farm/tests/test_ftmo_phase1_mae.py`.

## Dispatch safety evidence

At the dispatch decision, `farmctl work-items --status active` returned seven
active Q02 rows claimed by T1, T2, T3, T4, T6, T7, and T8. T5, T9, and T10
were parked in `disabled_terminals.txt`; the routed task required enabled
factory terminals. The enabled terminals immediately continued taking normal
queue work, so there was no collision-free slot for a serialized ad-hoc run.

A separate live Codex process was also observed with canonical checkout
`C:/QM/repo`, created at `2026-07-10 11:58:50` local time. The router's original
spawn lease had expired at `2026-07-10T09:29:33Z`; the task remained
`IN_PROGRESS`. This cycle did not overwrite or terminate that executor.

## Safety and scope

- No terminal process, metatester, worker, or active backtest was stopped.
- `terminal64.exe` was not started manually.
- T_Live and AutoTrading were not touched.
- No stream row, report metric, MAE value, or entry time was synthesized.
- No pipeline verdict, threshold, Q07 lineage, or paid-challenge readiness was
  inferred.
- The headless session had no `G:` drive mapping, so the optional company
  reference files were unavailable; the local active charter and profitability
  track were read.

## Controlled continuation

Recycle only after establishing single-executor ownership and obtaining a
collision-free enabled-terminal window. Rerun, serialized, the five remaining
stale sleeves: `10286/XTIUSD.DWX/D1`, `10692/NDX.DWX/H1`,
`10848/XAUUSD.DWX/H1`, `11476/USDJPY.DWX/H1`, and `12475/NDX.DWX/H1`.
For every target, retain the same-run `report.htm`, require report trade count
to equal fresh JSONL row count, and require numeric `entry_time` plus
`mae_acct` on every row. Run the final CE(S)T 30-day/60-day simulator only
after the exact verifier reaches `12/12`.
