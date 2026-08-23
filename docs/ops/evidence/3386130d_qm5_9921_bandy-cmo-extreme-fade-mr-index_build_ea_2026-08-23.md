# QM5_9921 Build Evidence — Bandy CMO Extreme Fade Long-Only Index MR D1

- Task ID: `3386130d-8fec-49ff-bf2c-c238d8807121` (`build_ea`, priority 50, assigned to Gemini)
- EA ID: `QM5_9921_bandy-cmo-extreme-fade-mr-index`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9921_bandy-cmo-extreme-fade-mr-index.md`
- Source: Howard B. Bandy, Quantitative Technical Analysis (2015), ISBN 9780979183850 (`9ef19e06-5ca6-5b35-aa06-b8187aa0e016`)
- Outcome: `SOURCE_READY_FOR_REVIEW`

## Governed Identity and Registries

- EA ID `9921` registered in `framework/registry/ea_id_registry.csv` as active.
- 13 active magic rows in `framework/registry/magic_numbers.csv` across slots 0..12 (base `99210000`):
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
- `framework/include/QM/QM_MagicResolver.mqh` contains active `9921` entries.

## Strategy Implementation

The EA implements Howard Bandy's CMO Extreme Fade (D1) mechanical mean-reversion rules:
- CMO calculation over 20 daily bars: $CMO = 100 \times \frac{\sum Up - \sum Down}{\sum Up + \sum Down}$.
- Macro regime filter: SMA(200) on closed D1 bars (Close > SMA(200)).
- Long entry: on closed bar 1, $CMO(20) \le -50.0$ AND $Close > SMA(200)$. Long-only.
- Exit signal: $CMO(20) \ge 0.0$ on closed bar (reversion back to neutral).
- Time stop: 8 trading days maximum holding period.
- Catastrophic stop loss: $2.5 \times ATR(14)$ below entry price.
- Risk model: `$1,000` fixed risk per trade in backtest (`RISK_FIXED=1000`, `RISK_PERCENT=0.0`).
- Framework conformance: `QM_FrameworkTrackOpenPositionMae()` on OnTick, news blackout compliance, Friday close handling, zero-initialized request.

## Focused Verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS (14 files checked, 0 findings, news stale max hours = 336).
- `validate_symbol_scope.py --fail-on-leak`: PASS (`SINGLE_SYMBOL_OK`, 0 violations).
- `build_gate_hardening.py`: PASS (0 failures, 0 warnings across D2–D18 checks).
- `backfill_setfile_strategy_params.py`: 13 backtest set files populated with complete scalar strategy parameters.

## Summary Verdict

`SOURCE_READY_FOR_REVIEW: EA source, SPEC.md, and setfiles complete; static build guardrails and symbol scope PASS; left in REVIEW for mandatory Codex review.`
