# QM5_9465 Build Evidence — Connors RSI 25 Pullback Mean Reversion D1

- Task: `1b490cf7-9172-410b-8e5b-07b24c0cb517` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_9465_connors-rsi25-d1`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9465_connors-rsi25-d1.md`
- Source MQ5 SHA-256: `286d70a1c6978b66b48983d132fc53984e9fad3865468d12ff0cadb6a2005713`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed Identity and Registries

- EA ID `9465` registered in `framework/registry/ea_id_registry.csv` with source `ef14a5d7-e3f1-52be-910a-3ca6b736a152` and slug `connors-rsi25-d1`.
- 13 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..12 (base `94650000`):
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
- `framework/include/QM/QM_MagicResolver.mqh` contains active `9465` entries.

## Strategy Implementation

The EA implements Larry Connors' 4-period RSI 25 Pullback Mean Reversion (D1) specification:
- Macro trend filter: Close > SMA(200) on closed D1 bars.
- Entry signal: RSI(4) < 25.0 in an uptrend, buying on next bar open.
- Exit signal: RSI(4) > 55.0 on closed D1 bar.
- Time-stop: 12 daily bars maximum holding period.
- Protective stop loss: `3.0 * ATR(14)` at entry.
- Spread filter: skip entry if spread > `0.25 * ATR(14)`.
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
