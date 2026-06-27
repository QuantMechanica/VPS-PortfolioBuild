# QM5_10009 Active Logical-Basket Q02 CPU-Ceiling State - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or live-manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. It has only two strict-threshold
survivors:

- `QM5_12533` EURJPY/GBPJPY D1 basket: logical-basket Q02 `PASS`; follow-on
  Q04 default probe `FAIL` with pooled PF 0.432 across 43 pooled trades.
- `QM5_12532` AUDUSD/NZDUSD D1 basket: logical-basket Q02 `PASS`; follow-on
  Q04 `FAIL` for low pooled fold trades.

There is still no qualified unbuilt third pair from the 66-pair scan. The
fallback path is therefore the existing approved FX basket `QM5_10009`
AUDUSD/NZDUSD/USDCAD cointegration basket. Commit `78b590de9` already added
the logical basket manifest/setfile and enqueued one non-duplicate Q02 row.

## Current Farm State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked at `2026-06-27T14:03:01Z` (`2026-06-27T16:03:01+02:00` local).

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `d3b23700-088a-4857-a91e-5f31e8ac6b39` |
| EA | `QM5_10009` |
| Symbol | `QM5_10009_AUD_NZD_CAD_COINTEG_D1` |
| Phase | `Q02` |
| Status | `active` |
| Claimed by | `T4` |
| Enqueued | `2026-06-27T13:23:19+00:00` |
| Started / claimed | `2026-06-27T13:32:13+00:00` |
| Host | `AUDUSD.DWX`, `D1` |
| Window | `2018.07.02` to `2024.12.31` |
| Effective trade floor | `35` |
| Setfile | `framework/EAs/QM5_10009_rw-fx-cointeg-bb/sets/QM5_10009_rw-fx-cointeg-bb_QM5_10009_AUD_NZD_CAD_COINTEG_D1_D1_backtest.set` |
| Basket manifest | `framework/EAs/QM5_10009_rw-fx-cointeg-bb/basket_manifest.json` |
| Report root | `D:/QM/reports/work_items/d3b23700-088a-4857-a91e-5f31e8ac6b39` |

The manifest declares the logical basket as `AUDUSD.DWX`, `NZDUSD.DWX`, and
`USDCAD.DWX`, with `AUDUSD.DWX` as the D1 host. The canonical Q02 setfile uses
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Process Evidence

- Worker payload points to runner `pwsh.exe` PID `17372`.
- T4 `terminal64.exe` PID `10132` was alive from `D:/QM/mt5/T4/terminal64.exe`.
- T4 `metatester64.exe` PID `9580` was alive from `D:/QM/mt5/T4/metatester64.exe`.
- Work-item log:
  `D:/QM/strategy_farm/logs/work_item_d3b23700-088a-4857-a91e-5f31e8ac6b39.log`.
- Tester config:
  `D:/QM/reports/work_items/d3b23700-088a-4857-a91e-5f31e8ac6b39/QM5_10009/20260627_133214/raw/run_01/tester.ini`.
- T4 terminal log showed this run launched at `15:32:15` local and progressed
  through `58 %` at `16:02:24` local.
- EA runtime log was updating at inspection time:
  `D:/QM/mt5/T4/Tester/Agent-127.0.0.1-3001/MQL5/Files/QM/QM5_10009_ea-10009.log`
  last modified `2026-06-27T16:02:58+02:00`.

## Stop Condition

No new Q02 row was inserted and no manual MT5 test was launched. The paced fleet
already owns the `QM5_10009` logical-basket Q02 run and all factory tester slots
were occupied, so starting another FX basket backtest would duplicate CPU work.
Stop here under the mission CPU-ceiling constraint; the next action is to let
the worker finish or reach timeout, then classify the Q02 verdict.
