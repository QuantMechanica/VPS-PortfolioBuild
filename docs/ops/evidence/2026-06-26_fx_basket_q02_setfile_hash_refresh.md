# FX Basket Q02 Setfile Hash Refresh - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` documents only two strict survivors from
the 66-pair FX cointegration scan:

- `QM5_12533` EURJPY/GBPJPY cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD cointegration basket.

No additional unbuilt FX cointegration pair from that scan met the documented threshold
(`DEV > 0`, `OOS net Sharpe > 0.8`, and `OOS trades >= 4`). I therefore advanced the existing
FX basket Q02 path instead of creating a weak duplicate card.

## Repo Action

Refreshed stale `build_hash` headers in the existing backtest setfiles for:

- `framework/EAs/QM5_12532_edgelab-audnzd-cointegration/sets/*.set`
- `framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/*.set`

Most importantly, the logical basket Q02 setfile for `QM5_12532` no longer carries
`build_hash: pending`.

## Queue State Verified

Logical basket Q02 rows remain pending in `D:/QM/strategy_farm/state/farm_state.sqlite`:

| EA | Work item | Logical symbol | Host symbol |
|---|---|---|---|
| `QM5_12532` | `e4890d77-b865-4a48-b946-315faefca920` | `QM5_12532_AUDNZD_COINTEGRATION_D1` | `AUDUSD.DWX` |
| `QM5_12533` | `fe14e345-8ea4-4fbd-a77d-831df5fedc51` | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` | `EURJPY.DWX` |

Both payloads include `portfolio_scope: basket`, `basket_manifest`, `host_symbol`, and
`host_timeframe`. The worker dispatch path uses the host symbol for MT5 while preserving the
logical basket symbol for evidence.

## Validation

- `build_check.ps1 -EALabel QM5_12532_edgelab-audnzd-cointegration -SkipCompile`:
  PASS, report `D:/QM/reports/framework/21/build_check_20260626_130228.json`.
- `build_check.ps1 -EALabel QM5_12533_edgelab-eurjpy-gbpjpy-cointegration -SkipCompile`:
  PASS, report `D:/QM/reports/framework/21/build_check_20260626_130229.json`.
- `QM_AGENT_ID=controller python -m unittest tools.strategy_farm.tests.test_basket_work_items`:
  PASS, 2 tests.

No backtest was launched in this cycle.
