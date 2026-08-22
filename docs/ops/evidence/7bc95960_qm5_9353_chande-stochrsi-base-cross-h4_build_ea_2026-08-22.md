# QM5_9353 Build Evidence — Chande Stochastic-RSI Base Cross H4

- Task: `7bc95960-7134-4d02-88c2-87ce2cb8761c` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_9353_chande-stochrsi-base-cross-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9353_chande-stochrsi-base-cross-h4.md`
- Source MQ5 SHA-256: `d41133892dcfeb01aff347777b549118f2ee275ab7eee1faf6b2be08caec991f`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed Identity and Registries

- EA ID `9353` registered in `framework/registry/ea_id_registry.csv` with source `6e967762-b26d-59a3-b076-35c17f2e7c36` and slug `chande-stochrsi-base-cross-h4`.
- 13 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..12 (base `93530000`):
  - 0: `GDAXI.DWX`
  - 1: `NDX.DWX`
  - 2: `SP500.DWX`
  - 3: `UK100.DWX`
  - 4: `WS30.DWX`
  - 5: `XAUUSD.DWX`
  - 6: `EURUSD.DWX`
  - 7: `GBPUSD.DWX`
  - 8: `USDJPY.DWX`
  - 9: `USDCHF.DWX`
  - 10: `AUDUSD.DWX`
  - 11: `USDCAD.DWX`
  - 12: `NZDUSD.DWX`
- `framework/include/QM/QM_MagicResolver.mqh` contains active `9353` entries.

## Strategy Implementation

The EA implements the approved Chande & Kroll Stochastic-RSI Base Cross (H4) specification:
- RSI(14) normalized over rolling 14-bar window with Chande neutral=0.5 convention for flat-RSI edge cases.
- %K = SMA(StochRSI, 3) and %D = SMA(%K, 3).
- Long entry: %K crosses above %D from oversold (< 0.20) and Close > SMA(200).
- Short entry: %K crosses below %D from overbought (> 0.80) and Close < SMA(200).
- Protective stop loss: `1.8 * ATR(14)` at entry.
- Exits: Opposite %K-%D cross in extreme zone, secondary opposite cross in profit >= 1.0 * ATR(14), and 25-bar time stop.
- Spread filter: skip entry if spread > `0.15 * ATR(14)`.
- Risk model: `$1,000` fixed risk per trade in backtest (`RISK_FIXED=1000`, `RISK_PERCENT=0.0`).
- Framework conformance: OnTick MAE hook, news compliance gate, Friday close handling, zero-initialized `QM_EntryRequest`.

## Focused Verification

- `validate_spec_doc.py`: PASS (1/1).
- `build_gate_hardening.py`: PASS (0 failures, 0 warnings across all D2-D11 checks).
- `validate_build_guardrails.py`: PASS (0 findings, 336 hr stale news ceiling).
- `validate_symbol_scope.py --fail-on-leak`: PASS (`SINGLE_SYMBOL_OK`, 0 violations).
- `gen_setfile.ps1`: 13 setfiles generated in `sets/` with valid parameters.

## Compile Boundary

Direct `build_check.ps1` and ad-hoc `compile_ea` safely stopped before compilation with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` / `INCLUDE_MIRROR_REFUSED` because live `terminal64.exe` factory worker processes are active. In accordance with hard rules, no terminal was started, stopped, or interrupted.

Short verdict: `SOURCE_READY_COMPILE_HELD: source and spec complete; static gates PASS; ad-hoc compile safely held while factory workers are active.`
