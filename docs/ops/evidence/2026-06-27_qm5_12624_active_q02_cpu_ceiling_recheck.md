# QM5_12624 Active Q02 CPU-Ceiling Recheck - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. The strict-threshold survivors are already built:

- `QM5_12533` EURJPY/GBPJPY: logical-basket Q02 `PASS`, later Q04 `FAIL`.
- `QM5_12532` AUDUSD/NZDUSD: logical-basket Q02 `PASS`, later Q04 `FAIL`.

The relaxed next-best FX cointegration candidates found in the local rerun have
also already been mechanized as basket EAs:

- `QM5_12624` EURJPY/AUDJPY.
- `QM5_12712` EURGBP/EURAUD.
- `QM5_12723` NZDUSD/EURJPY.

No unbuilt strict-threshold pair remained to card without duplicating existing
work. The correct action for this pass was to verify the existing `QM5_12624`
Q02 lane and stop because a worker-owned basket backtest is already active.

## Current Farm State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked during the 2026-06-27 Berlin evening fleet pass.

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `1489f74b-7259-484d-9237-452331b0e478` |
| EA | `QM5_12624` |
| Symbol | `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1` |
| Setfile | `framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/sets/QM5_12624_edgelab-eurjpy-audjpy-cointegration_QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set` |
| Status | `active` |
| Claimed by | `T7` |
| Created | `2026-06-27T19:47:43+00:00` |
| Updated at DB check | `2026-06-27T19:49:17+00:00` |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000`, `timeout_min=120` |

Process evidence:

- `D:/QM/mt5/T7/terminal64.exe` PID `10728`, started `2026-06-27 21:49:18` local.
- `D:/QM/mt5/T7/metatester64.exe` PID `16476`, started `2026-06-27 21:49:24` local.
- Work-item log reached `run_smoke.stage=terminal_spawn_confirmed terminal_pid=10728`.
- Terminal log showed `AutoTesting processing 48 %` at `2026-06-27 22:44:26` local.

## Stop Condition

No new Q02 row was inserted and no manual MT5 backtest was launched. Basket Q02
work is already occupying a paced terminal slot, so starting another FX basket
run would violate the mission CPU-ceiling constraint. The next useful action is
to let `1489f74b-7259-484d-9237-452331b0e478` finish or hit its configured
120-minute timeout, then classify that Q02 evidence.
