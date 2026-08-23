# QM5_9922 Build Evidence — Bandy Vortex Crossover Trend D1

- Task ID: `39477905-5cfe-43eb-bebf-3ad5ba8d10b3` (`build_ea`, priority 50, assigned to Gemini)
- EA ID: `QM5_9922_bandy-vortex-crossover-trend`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9922_bandy-vortex-crossover-trend.md`
- Source: Howard B. Bandy, Quantitative Technical Analysis (2015), ISBN 9780979183850 (`9ef19e06-5ca6-5b35-aa06-b8187aa0e016`)
- Outcome: `SOURCE_READY_FOR_REVIEW`

## Governed Identity and Registries

- EA ID `9922` registered in `framework/registry/ea_id_registry.csv` as active.
- 13 active magic rows in `framework/registry/magic_numbers.csv` across slots 0..12 (base `99220000`):
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
- `framework/include/QM/QM_MagicResolver.mqh` contains active `9922` entries.

## Strategy Implementation

The EA implements Howard Bandy's Vortex Crossover Trend (D1) mechanical rules:
- Vortex calculation over 14 daily bars: $VM^+_n = \sum |High[i] - Low[i+1]|$, $VM^-_n = \sum |Low[i] - High[i+1]|$, $TR_n = \sum TR_i$, $VI^+ = VM^+ / TR$, $VI^- = VM^- / TR$.
- Trend filter: ADX(14) >= 20.0 and SMA(200) regime gate (Close > SMA(200) for Long, Close < SMA(200) for Short).
- Noise filter: Reject entry if $|VI^+ - VI^-| < 0.05$ on the cross bar.
- Long entry: $VI^+$ crosses above $VI^-$ on completed bar 1 with ADX >= 20, Close > SMA(200), and $|VI^+ - VI^-| \ge 0.05$.
- Short entry: $VI^-$ crosses above $VI^+$ on completed bar 1 with ADX >= 20, Close < SMA(200), and $|VI^+ - VI^-| \ge 0.05$.
- Stop loss: Chandelier trailing stop ($HHV(High, 22) - 2.5 \times ATR(14)$ for long, $LLV(Low, 22) + 2.5 \times ATR(14)$ for short), ratcheted in direction of trade via `QM_TM_SendSLTPModify`.
- Time stop: 60 trading days maximum holding period.
- Exit signal: opposite Vortex crossover on closed bar.
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
