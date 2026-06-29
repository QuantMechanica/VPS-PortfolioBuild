# QM5_10185 Kumo Ichimoku Long Q02 Enqueue Evidence

Date: 2026-06-29

## Scope

- EA: `QM5_10185_tv-kumo-ichi-long`
- Build task: `0a8ba6d1-862d-4670-88e5-417ecd9d3b86`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10185_tv-kumo-ichi-long.md`
- Instrument scope: `EURJPY.DWX`, `GBPJPY.DWX`, `XAUUSD.DWX`, `NDX.DWX`, `GDAXI.DWX`
- Diversity note: adds two JPY FX crosses plus gold/index validation to the Q02 funnel.

## Build Changes

- Verified the Ichimoku, volume, trailing-stop, and defensive-exit history scans
  are behind `QM_IsNewBar(_Symbol, strategy_signal_tf)` so Model-4 tests do not
  run those loops on every tick.
- Added explicit `perf-allowed` annotations for the raw OHLC/volume reads so
  build_check accepts the bounded bespoke Ichimoku/tick-volume calculations.
- Added required Q01 `SPEC.md`.
- Generated five H1 backtest setfiles with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Validation

- Spec validation: PASS.
  - Command: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10185_tv-kumo-ichi-long`
- Build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260629_081950.json`
- Compile: PASS, 0 errors, 0 warnings.
  - Log: `C:\QM\repo\framework\build\compile\20260629_082015\QM5_10185_tv-kumo-ichi-long.compile.log`
  - Summary: `D:\QM\reports\compile\20260629_082015\summary.csv`
- `.mq5` SHA256: `202DC46FD222AFC3B72FBC74F28E99CFFED575B0060258EAE11A6ECC5DCE9D90`
- `.ex5` SHA256: `D80F46BCC5149FFFB5943966F07B5BA9D98A6245830C844904AED06EA7E1AB0F`

## Q02 Queue Evidence

Farm DB: `D:\QM\strategy_farm\state\farm_state.sqlite`

| Work item | Symbol | Status |
|---|---|---|
| `2278e24e-3219-4a46-ba78-ab5b3c1ff2ac` | `EURJPY.DWX` | pending |
| `8d2864b0-f235-417b-8d0f-732338997103` | `GBPJPY.DWX` | pending |
| `22d87027-5df7-42f4-aac7-80eb3bf14645` | `XAUUSD.DWX` | pending |
| `43e9a9c3-65a3-4566-8e36-b827042c94b1` | `NDX.DWX` | pending |
| `ce25ec93-9474-4c66-82fb-b96173423482` | `GDAXI.DWX` | pending |

Setfiles:

- `framework/EAs/QM5_10185_tv-kumo-ichi-long/sets/QM5_10185_tv-kumo-ichi-long_EURJPY.DWX_H1_backtest.set`
- `framework/EAs/QM5_10185_tv-kumo-ichi-long/sets/QM5_10185_tv-kumo-ichi-long_GBPJPY.DWX_H1_backtest.set`
- `framework/EAs/QM5_10185_tv-kumo-ichi-long/sets/QM5_10185_tv-kumo-ichi-long_XAUUSD.DWX_H1_backtest.set`
- `framework/EAs/QM5_10185_tv-kumo-ichi-long/sets/QM5_10185_tv-kumo-ichi-long_NDX.DWX_H1_backtest.set`
- `framework/EAs/QM5_10185_tv-kumo-ichi-long/sets/QM5_10185_tv-kumo-ichi-long_GDAXI.DWX_H1_backtest.set`

## Safety

- No `T_Live` files were edited.
- AutoTrading was not touched.
- No portfolio gate or T_Live manifest files were edited.
- No manual MT5 backtest was launched from this session; Q02 remains queued for the paced farm.
