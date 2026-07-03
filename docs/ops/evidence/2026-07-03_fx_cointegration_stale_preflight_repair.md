# FX Cointegration Stale-Preflight Repair - 2026-07-03

Branch: `agents/board-advisor`

## Scope

Mission was to grow the V5 forex sleeve with market-neutral FX cointegration
baskets, preferring `QM5_12532` / `QM5_12533` Q02 unblocks if either strict
survivor was still blocked.

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08 contribution,
portfolio gate, or deploy manifest files were touched.

## Research / Funnel State

Controlling research source:
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

That source documents only two strict 66-pair FX cointegration survivors:

| Pair | EA | Current state checked |
|---|---|---|
| `AUDUSD~NZDUSD` | `QM5_12532` | Q02 `PASS`, Q04 `PASS`, latest Q05 `FAIL` |
| `EURJPY~GBPJPY` | `QM5_12533` | Q02 `PASS`, later Q04 `FAIL` |

The latest non-duplicate FX cointegration build already on this branch,
`QM5_12978` (`GBPUSD~USDCAD`), has Q02 `PASS`, Q03 `PASS`, and Q04 `FAIL`.
I did not create another duplicate card from the strict scan.

## Work Done

The live work-items DB had pending FX cointegration rows still carrying stale
`preflight_failure: ea_dir_missing` payload/evidence from an older
`C:\QM\worktrees\codex-orchestration-1` path, while their current setfile,
EA dir, `.ex5`, and basket manifest all existed under `C:\QM\repo`.

I added `R17_clear_stale_preflight_work_item` to
`tools/strategy_farm/repair.py`. It clears stale preflight payload/evidence only
when the same artifact check used by R11 now passes, including the worker's
duplicate-EX5 guard. Rows with genuinely missing artifacts remain under R11.

Targeted live DB repair applied only to these FX rows:

| Work item | EA | Phase | Symbol | Action |
|---|---|---|---|---|
| `6a1a390b-7380-407e-a75d-6c64cec9a63f` | `QM5_12728` | Q04 | `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1` | cleared stale `ea_dir_missing`; row remains pending |
| `1c0405e7-16d3-40e6-b884-6be1b504dc4c` | `QM5_12778` | Q05 | `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` | cleared stale `ea_dir_missing`; row remains pending |

Both rows now have `evidence_path = NULL`, no `preflight_failure` payload, and
`stale_preflight_repair_handler = R17_clear_stale_preflight_work_item`.

## CPU Ceiling

No new Q02/Q04/Q05 row was enqueued. Queue status at verification still showed
five active factory work items, so I stopped at the backtest CPU ceiling rather
than adding duplicate tester work.

Active rows included:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T2 | `QM5_11095` | Q07 | `GBPUSD.DWX` |
| T3 | `QM5_10692` | Q05 | `GDAXI.DWX` |
| T1 | `QM5_12772` | Q07 | `QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1` |
| T5 | `QM5_10115` | Q05 | `XAUUSD.DWX` |
| T4 | `QM5_1061` | Q07 | `NDX.DWX` |

## Verification

- `python -m unittest tools.strategy_farm.tests.test_repair_stale_preflight` -> PASS
- `python -m unittest framework.scripts.tests.test_mt5_queue_status` -> PASS
- `python framework/scripts/mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 8` -> `schema: work_items`, active count `5`
