---
ea_id: QM5_1165
slug: unger-gold-linreg-trend
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-17
---

# Unger Gold Linear Regression Trend - H1 Regression Level Breakout

Source: Unger Academy March 2025 Strategy of the Month article, "A Trend-Following Strategy on Gold Futures"; local build copy omits external URL for build-check compliance.

Universe: `XAUUSD.DWX`. Execution timeframe: H1.

## Entry

1. Compute linear regression line over completed H1 closes, default `LR_PERIOD = 40`.
2. Compute regression residual standard deviation over the same window.
3. Define trigger levels:
   - `LR_UPPER = LR_VALUE + LR_DEV * RESID_STDEV`, default `LR_DEV = 1.0`.
   - `LR_LOWER = LR_VALUE - LR_DEV * RESID_STDEV`.
4. Long setup: completed H1 close crosses above `LR_UPPER`.
5. Short setup: completed H1 close crosses below `LR_LOWER`.
6. Enter at market on signal-bar close.
7. One position per magic.

## Exit

- Close on stop loss or take profit.
- Close long if H1 closes back below the regression line; close short if H1 closes back above the regression line.
- Max hold default: `MAX_HOLD_BARS = 72` H1 bars.

## Stop Loss / Take Profit

- `SL = 2.0 * ATR(14,H1)`
- `TP = 4.0 * ATR(14,H1)`

## Filters

- Trade only during liquid gold hours; manage open trades overnight.
- Skip FOMC, CPI, and NFP release windows via V5 high-impact news skip-day defaults.
- Standard V5 spread filters.
