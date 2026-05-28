# QM5_1194_qp-stress-spx-composite SPEC

## Intent

Build-only V5 EA for the approved Quantpedia Composite Stress SP500 Rebound card. The EA trades `SP500.DWX` long on D1 after a cross-asset stress day.

## Signal

- Evaluate only on new D1 bars.
- Compute prior completed D1 close-to-close returns for `SP500.DWX`, `XAUUSD.DWX`, and oil (`XTIUSD.DWX`, with `XBRUSD.DWX` fallback).
- Read deterministic Treasury total-return observations from `IEF_total_return.csv`.
- Confirm stress when at least `strategy_min_confirmations` of these three binary conditions are true:
  - SP500 return below threshold and gold return below threshold.
  - SP500 return below threshold and oil return below threshold.
  - SP500 return below threshold and Treasury proxy return above zero.

## Execution

- Entry: long `SP500.DWX`.
- Stop: D1 ATR(20) times `strategy_atr_sl_mult`, default `1.5`.
- Exit: next D1 close; safety exit after `strategy_safety_hold_days`, default `2`.
- One open position per magic number.

## Data Notes

The Treasury leg requires local file `IEF_total_return.csv` in terminal Files or Common Files. Missing or stale data intentionally blocks entries.

## V5 Alignment

- Magic: `QM_Magic(qm_ea_id, qm_magic_slot_offset)`.
- Risk: fixed USD for backtest sets, percent risk for live set.
- News: off by default, no custom external API.
- No backtests or pipeline phases in this build.
