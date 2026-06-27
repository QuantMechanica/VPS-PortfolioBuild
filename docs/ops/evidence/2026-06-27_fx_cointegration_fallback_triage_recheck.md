# FX Cointegration Fallback Triage Recheck - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold
market-neutral FX cointegration survivors:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | logical-basket Q02 `PASS`; logical-basket Q04 `FAIL` for zero pooled fold trades |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | one logical-basket Q02 row active on T7 |

No third unbuilt FX cointegration pair from that scan meets the documented build
threshold (`DEV > 0`, OOS net Sharpe `> 0.8`, and at least 4 OOS trades). I did
not create a weaker duplicate card.

## Current Q02 State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked at approximately `2026-06-27T10:16Z`.

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `76cb11ee-7e9d-4d75-be9d-626c205bca62` |
| Parent task | `qm5-12533-post-claimfix-q02-requeue-20260627_083635-76cb11ee` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Status | `active` |
| Claimed by | `T7` |
| Created | `2026-06-27T08:37:07+00:00` |
| Started | `2026-06-27T09:26:44+00:00` |
| Timeout | `120` minutes |
| Host | `EURJPY.DWX`, `D1` |
| Tester currency / deposit | `JPY`, `15000000` |
| Risk fixed | `150000` JPY |
| Payload scope | `portfolio_scope=basket`, `priority_track=true` |
| Supersedes | `433bf1fd-c82f-4d3f-934c-21b772eea5fc` |

Process verification at the same check:

- Worker: `pythonw.exe` PID `600`, `terminal_worker.py --terminal T7`.
- Runner: `pwsh.exe` PID `912`, `run_smoke.ps1`, `TimeoutSeconds 7200`,
  `TesterCurrencyOverride JPY`.
- MT5: `terminal64.exe` PID `11644`, path `D:/QM/mt5/T7/terminal64.exe`.
- Tester: `metatester64.exe` PID `760`, path `D:/QM/mt5/T7/metatester64.exe`.

## Fallback Triage

I checked existing FX fallback candidates instead of launching a duplicate basket
test:

- `QM5_12580_fx-usd-exhaustion-reversal`: already reached Q04; latest Q04 rows
  for EURUSD, NZDUSD, USDCAD, USDCHF, and USDJPY are all `FAIL`.
- `QM5_12562_fx-london-open-breakout`: already reached Q02; EURUSD, GBPUSD, and
  USDJPY rows are `FAIL` or `INFRA_FAIL`, with no unblocked PASS path.

No new Q02 row was inserted and no manual MT5 run was launched. The priority
forex cointegration basket is already consuming a paced T7 worker slot, so
starting another FX basket run in this pass would duplicate worker-owned CPU
work. The next useful action is to let `76cb11ee-7e9d-4d75-be9d-626c205bca62`
finish or hit its 120-minute timeout, then classify the resulting Q02 evidence.
