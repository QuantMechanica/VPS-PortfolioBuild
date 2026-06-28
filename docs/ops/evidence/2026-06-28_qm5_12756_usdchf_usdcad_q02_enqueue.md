# QM5_12756 USDCHF/USDCAD Cointegration Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`QM5_12532` and `QM5_12533` are no longer Q02-blocked. Existing EdgeLab FX
cointegration baskets through `QM5_12751` are already built or queued. A
read-only rerun of `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`
on `D:/QM/mt5/T_Export/MQL5/Files` ranked `USDCHF.DWX` / `USDCAD.DWX` as the
next unbuilt OOS-positive 66-pair scan candidate.

This is explicitly sub-threshold research, not a survivor claim: DEV Sharpe
`-0.00`, OOS net Sharpe `0.13`, OOS return `+1.06%`, 16 OOS state changes,
hedge `0.55`, and 83-day half-life.

## Build

- EA: `QM5_12756_edgelab-usdchf-usdcad-cointegration`
- Logical symbol: `QM5_12756_USDCHF_USDCAD_COINTEGRATION_D1`
- Host: `USDCHF.DWX`, `D1`
- Basket legs: `USDCHF.DWX`, `USDCAD.DWX`
- Risk mode: backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Compile: `compile_one.ps1 -Strict` PASS, 0 errors, 0 warnings
- Build check: PASS, 0 failures, 16 framework-include advisory warnings

## Queue Action

Inserted one non-duplicate logical-basket Q02 row in
`D:/QM/strategy_farm/state/farm_state.sqlite`.

| Field | Value |
|---|---|
| Work item | `3a06b01c-7b8c-4db0-86fb-d40e0a1c0000` |
| Status after first worker touch | `pending` after one `T5` launch fault |
| Setfile | `framework/EAs/QM5_12756_edgelab-usdchf-usdcad-cointegration/sets/QM5_12756_edgelab-usdchf-usdcad-cointegration_QM5_12756_USDCHF_USDCAD_COINTEGRATION_D1_D1_backtest.set` |
| Basket manifest | `framework/EAs/QM5_12756_edgelab-usdchf-usdcad-cointegration/basket_manifest.json` |
| Tester currency/deposit | `USD`, `100000` |
| Timeout | `120` minutes |
| DB backup | `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12756_q02_enqueue_20260628_210933Z.sqlite` |

No manual MT5 run was launched. The paced worker claimed the row on `T5`, hit a
sub-second launch fault (`0.09s`), and returned it to pending cooldown until
`2026-06-28T21:16:10Z`.
