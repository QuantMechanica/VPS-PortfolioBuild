# QM5_12778 Q04 NO_HISTORY Retry

Date: 2026-07-01 (Europe/Berlin)
Branch: `agents/board-advisor`

## Scope

- EA: `QM5_12778_edgelab-audusd-eurjpy-cointegration`
- Pair: `AUDUSD.DWX` / `EURJPY.DWX`
- Logical basket symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- Conversion history declared in manifest: `EURUSD.DWX`
- Host/timeframe: `AUDUSD.DWX`, `D1`
- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Selection

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
FX cointegration scan. The strict survivors, `QM5_12533` and `QM5_12532`, are
not Q02-blocked:

| EA | Current state |
|---|---|
| `QM5_12532` | Q02 PASS, Q04 PASS, later Q05 `INFRA_FAIL` with timeout/incomplete-run CPU-ceiling evidence |
| `QM5_12533` | Q02 PASS, later Q04 FAIL on completed combined basket metrics |

No unbuilt allocated EdgeLab FX cointegration pair was found after the existing
build set through `QM5_12803`, so this pass used the mission fallback: advance
an existing forex basket without duplicating work.

`QM5_12778` was selected because it has Q02 PASS and Q03 PASS, and its only Q04
row had completed as an infrastructure failure with no pending/active duplicate.
The prior Q04 aggregate at
`D:/QM/reports/work_items/9546f319-dc02-4249-b6ac-0c1bb64fec4f/QM5_12778/Q04/QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1/aggregate.json`
reported both folds invalid with `NO_HISTORY`, zero bars, empty report metadata,
and incomplete-run markers.

## Queue Action

Before mutating farm state, the DB was backed up:

```text
D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12778_q04_retry_20260701_231659.sqlite
```

Supported command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12778 --phase Q04
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `9546f319-dc02-4249-b6ac-0c1bb64fec4f` |
| Created rows | `0` |
| Skipped rows | `0` |
| Status after enqueue | `pending` |
| Updated at | `2026-07-01T21:17:02+00:00` |
| Archived prior report root | `D:/QM/reports/work_items/9546f319-dc02-4249-b6ac-0c1bb64fec4f.requeued_20260701T2117020000` |

Post-action verification:

- `farmctl work-items --ea QM5_12778`: Q02 done PASS, Q03 done PASS, Q04 pending.
- Direct SQLite duplicate guard: exactly one pending/active Q04 row for
  `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`.
- Basket payload remains scoped to host `AUDUSD.DWX`, logical symbol
  `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`, `tester_currency=EUR`, and
  `tester_deposit=100000`.
- The payload keeps `RISK_FIXED=1000`, `RISK_PERCENT=0`, and Q04 history symbols
  `AUDUSD.DWX`, `EURJPY.DWX`, and `EURUSD.DWX`.

## Safety

- No manual MT5 backtest was launched; paced workers own execution.
- No backtest CPU ceiling was hit during this action.
- No `T_Live` path was touched.
- AutoTrading was not touched.
- No portfolio admission, KPI, Q08 contribution, deploy manifest, or portfolio
  gate file was touched.

Machine-readable evidence:
`artifacts/qm5_12778_q04_nohistory_retry_20260701.json`.
