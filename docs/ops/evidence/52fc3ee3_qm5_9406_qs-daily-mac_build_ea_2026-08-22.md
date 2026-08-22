# QM5_9406 Build Evidence — QuantStart Daily SMA Crossover

- Task: `52fc3ee3-bd54-41c4-a3fd-d3616da86b62` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_9406_qs-daily-mac`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9406_qs-daily-mac.md`
- Source MQ5 SHA-256: `23bc76a30cadb074ca66c66ffcd9a5602222cd1649232a433ed29510d0c4c5cf`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed Identity and Registries

- EA ID `9406` registered in `framework/registry/ea_id_registry.csv` with source `842161b9-a728-55c7-97e8-33e33719b70c` and slug `qs-daily-mac`.
- 13 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..12 (base `94060000`):
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
- `framework/include/QM/QM_MagicResolver.mqh` contains active `9406` entries.

## Strategy Implementation

The EA implements the approved QuantStart Daily SMA Crossover specification:
- Fast SMA (100) and Slow SMA (400) computed on closed D1 bars.
- Long-only entry triggered when 100-day SMA crosses above 400-day SMA after 400 warmup bars.
- Exit triggered when 100-day SMA crosses below or equals 400-day SMA.
- Protective stop loss: `2.5 * ATR(14)` at market ask.
- Spread filter: skip entry if spread > `0.30 * ATR(14)`.
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
