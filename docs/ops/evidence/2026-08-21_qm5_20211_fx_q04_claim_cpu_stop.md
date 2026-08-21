# QM5_20211 FX cointegration Q04 claim verification and hard CPU stop

Date: 2026-08-21 UTC (`2026-08-21T20:18:01Z`)

Branch: `agents/board-advisor`

Status: the previously prioritized rank-31 FX basket is now active exactly
once at Q04; stopped at the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in commit `a80493291` maps all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`; another Card, registry
allocation, basket manifest, or EA would duplicate governed work.

The preferred anchors remain beyond Q02 rather than blocked by ONINIT or
NO_HISTORY:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The rank-21 fallback observed pending earlier on 2026-08-21 has now reached a
terminal Q04 FAIL: `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`, work item
`113ae6d1-33c0-42bc-b9b0-bf3a48ef3445`. It was not requeued.

## Existing-pair advancement verified

Commit `e61b1b5d6` advanced the first non-duplicate successor in place by
priority-marking the one existing Q04 row for rank 31,
`GBPJPY.DWX` / `EURAUD.DWX`, implemented as `QM5_20211_gbpjpy-euraud`.
The package retains its approved structural Chan lineage, frozen scan beta,
and one-shot no-refit/no-rescue boundary.

At `2026-08-21T20:18:01Z`, the canonical work-item view showed:

- logical Q02 predecessor `21db772c-c974-4a05-8e21-5ec78659e988`: PASS;
- logical Q04 successor `8135f97c-fd0d-4435-b713-87fa74fe0053`: active;
- exactly one claim, by paced factory terminal `T6`;
- attempt count zero, no verdict yet, and no duplicate successor.

The logical basket remains D1 and market-neutral across the two traded legs.
Its backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; no package artifact was changed.

## Binding CPU stop

A fresh five-sample CPU observation was `99.81%`, `99.91%`, `100.00%`,
`100.00%`, and `98.75%` (average `99.69%`, maximum `100.00%`). The maximum
exceeded the explicit `97%` hard ceiling.

Per the mission stop rule, no enqueue, requeue, priority mutation, dispatch
tick, tester launch, terminal reservation, terminal reconciliation, or
terminal control followed. The already-active paced Q04 item was left to its
owner.

Machine-readable evidence:
`artifacts/fx_cointegration_qm5_20211_q04_claim_cpu_stop_20260821T201801Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, terminal, or AutoTrading state changed.
- No Card, EA, EX5, setfile, basket manifest, registry, magic row, or queue row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
