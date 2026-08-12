# FX cointegration frontier reconciliation and paced CPU stop

Date: 2026-08-12

Branch: `agents/board-advisor`

Status: frontier exhausted; rank-58 existing logical basket Q02 remains
PENDING; stopped at the paced backtest CPU ceiling

## Outcome

No new FX Card or EA was created because that would duplicate the frozen
66-pair frontier. A fresh relationship-level audit reproduced all 66 ranks from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges` and matched every relationship to at least one exact
logical Q02 identity. The latest exact identities comprise 54 Q02 PASS, nine
Q02 FAIL, one INFRA_FAIL, and two PENDING relationships. There are zero
uncovered relationships.

The concrete existing-pair fallback is rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, in approved `QM5_1257_lemishko-fx-cointpair` pair slot 8. It is
the highest-ranked relationship without a terminal exact logical Q02 verdict.
Its single Q02 work item, `d4cd660c-c81a-41d3-8a4c-ad21d3319816`, was still
PENDING, unclaimed, and at attempt zero. It was preserved without a duplicate
enqueue or requeue.

## Anchor triage

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical logical Q02 PASS and
  Q04 PASS followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical logical Q02 PASS
  followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Selected existing relationship

Rank 58 has adverse frozen scan evidence: DEV net Sharpe
`-0.103537893720`, OOS net Sharpe `-0.419922430787`, OOS return
`-3.600289808739%`, 16 OOS state changes, DEV beta `-0.388288093234`, and a
`76.715376014881`-bar D1 half-life. Its Q02 binding is therefore a one-shot
cadence/economics test. A failure retires the binding; it does not authorize
refitting, filters, or rescue tuning.

The existing Card cites Lemishko, Landi, and Caicedo-Llano (2024),
“Cointegration-Based Strategies in Forex Pairs Trading,” SSRN 4771108. The
durable farm copy is OWNER-approved with R1-R4 PASS. The relationship already
has:

- a two-leg `basket_manifest.json` for `GBPUSD.DWX` and `USDJPY.DWX`;
- a logical H1 backtest setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- prior strict Q01 PASS evidence; and
- exactly one pending logical Q02 row under task
  `39ee6910-5d04-4087-83b0-65a6fd6b22f9`.

The other unresolved relationship is lower-ranked rank 65,
`USDCHF.DWX` / `AUDUSD.DWX`, which already has its own exact pending logical
Q02 row under `QM5_1156`. It was not duplicated or displaced.

## Binding paced CPU ceiling

The read-only `farmctl.py mt5-slots` sample at `2026-08-12T11:21:37Z` found
three factory terminals running: `T4`, `T8`, and `T9`. The current paced launch
gate in `D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`; three running
factory jobs therefore exceed the active paced ceiling. `T_Live` and the FTMO
terminal were observed only to exclude them from the factory count and were
not controlled.

Per the mission stop rule, no Card, EA, registry, queue, dispatch, reservation,
tester, or terminal-control mutation followed. No manual backtest was run.
AutoTrading, the T_Live manifest, portfolio admission/KPI/Q08 contribution
paths, and live artifacts were untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`.
