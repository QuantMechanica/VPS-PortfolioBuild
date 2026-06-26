# FX Basket Q02 Stale Leg Retire - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Context

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` shows only two strict survivors from the
66-pair FX cointegration scan:

- `QM5_12533` EURJPY/GBPJPY cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD cointegration basket.

Both EAs already have `basket_manifest.json` and logical basket Q02 setfiles. The live farm DB also
had the logical Q02 rows pending, but retained stale standalone-leg Q02 rows from the pre-manifest
path. Those leg rows reported `NO_HISTORY`, `ONINIT_FAILED`, `MIN_TRADES_NOT_MET`, and mixed
standalone pass/fail results, which are not valid verdicts for the market-neutral baskets.

## DB Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup taken before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_fx_basket_stale_leg_retire_20260626_120111.sqlite`

Retired as `status='failed', verdict='INVALID'` with payload reason
`basket_manifest_logical_q02_supersedes_component_leg_rows`:

| EA | Phase | Stale symbol rows retired |
|---|---:|---:|
| `QM5_12532` | Q02 | 6 |
| `QM5_12533` | Q02 | 26 |
| `QM5_12532` | Q04 | 1 |

The Q04 row was the stale child promoted from the old standalone `NZDUSD.DWX` Q02 pass, not a basket
walk-forward.

An event row was inserted in `events`:

`retire_stale_fx_basket_component_rows`

## Verified Final State

Logical basket Q02 rows remain pending:

| EA | Work item | Symbol | Status |
|---|---|---|---|
| `QM5_12532` | `e4890d77-b865-4a48-b946-315faefca920` | `QM5_12532_AUDNZD_COINTEGRATION_D1` | `pending` |
| `QM5_12533` | `fe14e345-8ea4-4fbd-a77d-831df5fedc51` | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` | `pending` |

Component-leg Q02 rows are now terminal-invalid only:

| EA | Symbol | Final state |
|---|---|---:|
| `QM5_12532` | `AUDUSD.DWX` | 3 x `failed/INVALID` |
| `QM5_12532` | `NZDUSD.DWX` | 3 x `failed/INVALID` |
| `QM5_12533` | `EURJPY.DWX` | 13 x `failed/INVALID` |
| `QM5_12533` | `GBPJPY.DWX` | 13 x `failed/INVALID` |

No backtest was launched; this was queue hygiene to let the already-enqueued logical baskets be the
only active Q02 path for these FX sleeves.
