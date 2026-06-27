# QM5_12533 JPY-Deposit Active Q02 CPU-Ceiling State - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold market-neutral
FX cointegration survivors:

| EA | Pair | Current funnel state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | logical-basket Q02 `PASS`; later logical-basket Q04 `FAIL` for low pooled fold trades |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | replacement logical-basket Q02 active after JPY tester-deposit repair |

No third unbuilt FX cointegration pair from the scan meets the documented strict build
threshold (`DEV > 0`, OOS net Sharpe > 0.8, and at least 4 OOS trades). Creating another
card from that scan would be a weak duplicate rather than new certified-book breadth.

## Live Farm State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked at `2026-06-27T04:48Z` (`2026-06-27T06:48+02:00` local).

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `12165577-fb9d-40c3-a527-f41c57cb8c45` |
| Parent task | `qm5-12533-jpy-deposit-q02-requeue-20260627_035634-12165577` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Setfile | `framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |
| Status | `active` |
| Claimed by | `T4` |
| Enqueued | `2026-06-27T03:56:37+00:00` |
| Started | `2026-06-27T04:30:09+00:00` |
| Timeout | `120` minutes |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000`, `priority_track=true` |
| Supersedes | `6a3884da-336b-4903-85a3-45d00e9ab9bf` |
| Report root | `D:/QM/reports/work_items/12165577-fb9d-40c3-a527-f41c57cb8c45` |

Latest run log:

- `D:/QM/strategy_farm/logs/work_item_12165577-fb9d-40c3-a527-f41c57cb8c45.log`
- `run_smoke.tester_deposit_manifest=15000000`
- `run_smoke.tester_currency_override=JPY`
- `run_smoke.stage=terminal_spawn_confirmed terminal_pid=7824 start_time='2026-06-27T06:30:10.5196795+02:00'`

The logical basket setfile is still `RISK_FIXED=150000`, matching the JPY tester-currency
repair documented in `docs/ops/evidence/2026-06-27_qm5_12533_jpy_deposit_q02_requeue.md`.

## Stop Condition

No new Q02 row was inserted and no manual backtest was launched. MT5/metatester CPU was
already occupied by active paced-worker runs, including the `QM5_12533` T4 basket run.

Under the mission CPU-ceiling constraint, the correct action is to stop here and let the
paced worker finish or time out this replacement Q02 row. The next useful action is to
classify the resulting `12165577-fb9d-40c3-a527-f41c57cb8c45` Q02 verdict after the worker
writes its summary.
