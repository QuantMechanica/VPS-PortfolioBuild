# QM5_12624 FX Cointegration Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. The scan's strict build threshold produced only
`QM5_12533` and `QM5_12532`; both now have logical-basket Q02 `PASS` rows in
`D:/QM/strategy_farm/state/farm_state.sqlite`.

No unbuilt strict-threshold pair remains. Per the mission fallback, I advanced
an existing forex basket instead of creating a duplicate weaker card.

## Queue Action

Requeued `QM5_12624` EURJPY/AUDJPY cointegration for logical-basket Q02.

| Field | Value |
|---|---|
| New work item | `1489f74b-7259-484d-9237-452331b0e478` |
| EA | `QM5_12624` |
| Symbol | `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1` |
| Status at verify | `pending` |
| Supersedes | `9461ba0f-5de6-490e-8d85-380738abd892` |
| Prior verdict | `INFRA_FAIL` |
| Setfile | `framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/sets/QM5_12624_edgelab-eurjpy-audjpy-cointegration_QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set` |
| Host symbol/timeframe | `EURJPY.DWX`, `D1` |
| Basket manifest | `framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/basket_manifest.json` |
| Tester currency/deposit | `JPY`, `15000000` |
| Risk fixed | `150000` |
| Timeout | `120` minutes |
| Enqueued by | `codex_board_advisor_qm5_12624_post_infra_q02_requeue_2026-06-27` |

Payload note:

`Requeued logical-basket Q02 with manifest host symbol and JPY tester deposit/risk; no manual MT5 launch.`

## CPU Ceiling

At verification, `QM5_12723` was the active basket Q02 job:

| Field | Value |
|---|---|
| Work item | `a12c992f-377e-4a71-8823-4f6faea2c6fc` |
| EA | `QM5_12723` |
| Symbol | `QM5_12723_NZDUSD_EURJPY_COINTEGRATION_D1` |
| Claimed by | `T6` |
| Runner PID | `10048` |
| Host symbol/timeframe | `NZDUSD.DWX`, `D1` |

Terminal workers serialize basket Q02 work, so `QM5_12624` should remain pending
until the active `QM5_12723` basket clears. No duplicate MT5 run was launched.
