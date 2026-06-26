# FX Cointegration Next-Pair Triage and Q02 State - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling 66-pair scan
artifact for the market-neutral FX cointegration sleeve search. It names only two pairs
that cleared the strict build threshold (`DEV > 0`, OOS net Sharpe > 0.8, and at least
4 OOS trades):

| EA | Pair | Scan status | Current funnel state |
|---|---|---|---|
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | strongest survivor, DEV 0.59 and OOS net Sharpe 1.53 | built; logical-basket Q02 still in progress |
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | second survivor, DEV 0.13 and OOS net Sharpe 1.29 | built; logical-basket Q02 passed, later Q04 low-frequency strategy failure |

No third unbuilt FX cointegration pair from that scan meets the documented build threshold.
Per the mission fallback, the correct action is to advance an existing FX basket instead of
creating a weaker duplicate card.

## Queue State Checked

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `e13e4576-f46d-446e-bd3a-ce70ec4ae9fd` |
| Parent task | `f6c61664-fed0-4c14-9092-b6282d335079` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Host | `EURJPY.DWX`, `D1` |
| Status | `active` |
| Claimed by | `T3` |
| MT5 PID | `10900` |
| Started | `2026-06-26T21:04:19+00:00` |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `timeout_min=120`, `priority_track=true` |
| Report root | `D:/QM/reports/work_items/e13e4576-f46d-446e-bd3a-ce70ec4ae9fd` |

The active row has moved past the prior zero-output launch fault:

- `run_smoke.stage=ini_written`
- `run_smoke.tester_currency_override=JPY`
- `run_smoke.stage=terminal_spawn_confirmed terminal_pid=10900`

No additional Q02 row was inserted because doing so while this work item is active would be
a duplicate. No tester was launched manually; the paced terminal worker owns the run.

## Stop Condition

The active MT5 process is still running under the worker. Stopped here under the mission's
CPU-ceiling discipline: the next useful action is to let the worker finish and then classify
the resulting Q02 verdict or infra failure.
