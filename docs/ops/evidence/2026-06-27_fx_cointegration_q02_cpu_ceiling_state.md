# FX Cointegration Q02 CPU-Ceiling State - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. It names only two strict-threshold survivors:

| EA | Pair | Current funnel state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | logical-basket Q02 `PASS`; later logical-basket Q04 `FAIL` for zero pooled fold trades |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | logical-basket Q02 actively running under worker ownership |

No third unbuilt FX cointegration pair from the scan meets the documented build threshold
(`DEV > 0`, OOS net Sharpe > 0.8, and at least 4 OOS trades). Per the mission fallback,
the correct action is to advance or unblock the existing FX baskets rather than create a
weaker duplicate card.

## Live Farm State Checked

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked at `2026-06-27T00:19:57Z`.

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `e9e4e602-77e2-441f-8709-a13ec0285496` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Host | `EURJPY.DWX`, `D1` |
| Status | `active` |
| Claimed by | `T1` |
| Parent process | `pwsh.exe` PID `12424` |
| MT5 process | `terminal64.exe` PID `12320` |
| Started | `2026-06-26T23:16:43+00:00` |
| Age at check | about 62 minutes |
| Timeout | `120` minutes |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `priority_track=true` |
| Report root | `D:/QM/reports/work_items/e9e4e602-77e2-441f-8709-a13ec0285496` |

Process verification:

- `pwsh.exe` PID `12424` was running `framework/scripts/run_smoke.ps1`.
- Child `terminal64.exe` PID `12320` was alive from `D:/QM/mt5/T1/terminal64.exe`.
- The EA log `D:/QM/mt5/T1/Tester/Agent-127.0.0.1-3008/MQL5/Files/QM/QM5_12533_ea-12533.log`
  was still updating at `2026-06-27 02:19:26` local time.

## Stop Condition

No new Q02 row was inserted and no manual tester was launched. Starting another FX basket
backtest while `QM5_12533` is already active would duplicate worker-owned CPU work. The
proper next action is to let the paced worker finish or reach the 120-minute basket timeout,
then classify the resulting Q02 verdict or infra failure.

