# QM5_12624 FX Next-Pair Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It hard-certified only:

- `QM5_12533` EURJPY/GBPJPY D1, already built; logical-basket Q02 PASS, later
  Q04 FAIL.
- `QM5_12532` AUDUSD/NZDUSD D1, already built; logical-basket Q02 PASS, later
  Q04 FAIL.

No third unbuilt strict-threshold FX cointegration pair was available from that
scan. `QM5_12624` EURJPY/AUDJPY is already built as the next-best exploratory
common-JPY pair, so this pass advanced that existing forex basket instead of
creating a duplicate card.

## Prior Failure

Latest completed `QM5_12624` logical-basket Q02 row before this requeue:

| Field | Value |
|---|---|
| Work item | `53f8fa92-3452-48ed-9e7c-82344a76883c` |
| Status / verdict | `done` / `INFRA_FAIL` |
| Evidence | `D:/QM/reports/work_items/53f8fa92-3452-48ed-9e7c-82344a76883c/QM5_12624/20260627_151534/summary.json` |
| Reason classes | `REPORT_MISSING`, `METATESTER_HUNG`, `INCOMPLETE_RUNS` |

The tester log tail showed real EURJPY/AUDJPY basket trades, so this was not an
`ONINIT` or `NO_HISTORY` failure. The original auto-enqueued row also lacked the
explicit basket priority, timeout, deposit, and fixed-risk metadata used by the
successful 12532/12533 logical-basket Q02 lanes.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12624_q02_requeue_20260627_160505Z.sqlite`

Inserted one replacement logical-basket Q02 work item after duplicate guard
found zero pending/active rows for `QM5_12624`:

| Field | Value |
|---|---|
| Work item | `9461ba0f-5de6-490e-8d85-380738abd892` |
| Parent task | `qm5-12624-reportmissing-q02-requeue-20260627_160505-9461ba0f` |
| EA | `QM5_12624` |
| Symbol | `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1` |
| Setfile | `C:/QM/repo/framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/sets/QM5_12624_edgelab-eurjpy-audjpy-cointegration_QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set` |
| Basket manifest | `C:/QM/repo/framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/basket_manifest.json` |
| Risk payload | `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |
| Supersedes | `53f8fa92-3452-48ed-9e7c-82344a76883c` |

## Current State

At verification, the replacement row had already been claimed by the paced T7
terminal worker:

| Field | Value |
|---|---|
| Status | `active` |
| Claimed by | `T7` |
| Created | `2026-06-27T16:05:06+00:00` |
| Updated | `2026-06-27T16:05:22+00:00` |

No manual MT5 backtest was launched. Execution is left to the paced terminal
worker under the CPU-ceiling constraint.
