# QM5_12751 FX Cointegration Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The strict 66-pair scan survivors `QM5_12532` and `QM5_12533` are no longer
Q02-blocked. Existing EdgeLab FX baskets through `QM5_12749` are already built
or queued, and the branch already contained `QM5_12751` for the next unqueued
OOS-positive scan pair: `EURUSD.DWX` / `EURAUD.DWX`. This pass verified that
existing build and advanced it into Q02.

This is explicitly sub-threshold research, not a survivor claim. The scan rerun
ranked it at DEV Sharpe `-0.02`, OOS net Sharpe `0.16`, OOS return `+1.28%`,
15 OOS state changes, hedge `0.34`, and 172-day half-life.

## Build

- EA: `QM5_12751_edgelab-eurusd-euraud-cointegration`
- Logical symbol: `QM5_12751_EURUSD_EURAUD_COINTEGRATION_D1`
- Host: `EURUSD.DWX`, `D1`
- Basket legs: `EURUSD.DWX`, `EURAUD.DWX`
- Conversion history selected by EA: `AUDUSD.DWX`
- Risk mode: backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Compile: `compile_one.ps1 -Strict` PASS, 0 errors, 0 warnings
- Build check: PASS, 0 failures, 16 framework-include advisory warnings

## Queue Action

Inserted one non-duplicate logical-basket Q02 row in
`D:/QM/strategy_farm/state/farm_state.sqlite`.

| Field | Value |
|---|---|
| Work item | `0480d11b-9754-4586-b461-e4e677fb58dc` |
| Status at insert | `pending` |
| Setfile | `framework/EAs/QM5_12751_edgelab-eurusd-euraud-cointegration/sets/QM5_12751_edgelab-eurusd-euraud-cointegration_QM5_12751_EURUSD_EURAUD_COINTEGRATION_D1_D1_backtest.set` |
| Basket manifest | `framework/EAs/QM5_12751_edgelab-eurusd-euraud-cointegration/basket_manifest.json` |
| Tester currency/deposit | `USD`, `100000` |
| Timeout | `120` minutes |
| DB backup | `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12751_q02_enqueue_20260628_162312.sqlite` |

At enqueue time the farm had 3 active worker-owned backtests and 5411 pending
backtest rows. The paced worker claimed the row immediately after insertion,
then returned it to `pending` after a fast launch fault on `T1`
(`last_launch_fault_seconds=0.09`, `launch_not_before_utc=2026-06-28T16:29:05+00:00`).
No manual MT5 run was launched.
