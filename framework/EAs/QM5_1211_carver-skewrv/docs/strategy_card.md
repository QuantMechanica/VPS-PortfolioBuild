---
ea_id: QM5_1211
slug: carver-skewrv
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
---

# QM5_1211 Carver Relative-Value Skew Rule

Relative-value version of the skew rule. It compares an instrument's rolling skew to the current median rolling skew of its asset-class group and trades the instruments whose skew is unusually positive or negative relative to their peers.

## Mechanik

- On each closed D1 bar for each asset-class group:
  - Compute log close returns.
  - Compute `skew_x = Skewness(r_x, Lookback)`.
  - Compute `group_skew = median(skew_x across valid instruments in group)`.
  - Compute `rv_signal_x = skew_x - group_skew`.
  - Compute `forecast_x = ForecastScalar * rv_signal_x / RollingMAD(rv_signal_x, 252)`.
  - Cap forecast to `[-20,+20]`.
- LONG instrument `x` if `forecast_x > EntryForecast`.
- SHORT instrument `x` if `forecast_x < -EntryForecast`.
- Default variant: `Lookback=365`, `EntryForecast=2`.
- P3 sweep variants: `Lookback in {180,365}` first; optional exploratory `{90}` if trade count is too low.

## Universe

- Index group: `GER40.DWX`, `NDX.DWX`, `WS30.DWX`.
- FX-major group: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.

## Exit

- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Re-rank once per D1 bar; cap open positions to `MaxSlotsPerGroup=2` by absolute forecast.

## Stop Loss

- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.5`, `3.0`, `3.5` ATR.

## Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Equal risk per open slot. One position per symbol/magic.

## Additional Filters

- Require at least three valid instruments in the group.
- Require at least `Lookback + 252` bars before trading.
- Skip when rolling MAD is zero or invalid.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs for RV skew and live weights. |
| R2 Mechanical | PASS | Rolling skew, group median demeaning, forecast scaling/cap, and exit rules are deterministic. |
| R3 DWX-testbar | PASS | Uses daily close returns inside DWX FX or index groups. |
| R4 No ML | PASS | Fixed lookback and group construction, bounded slots, one position per symbol/magic, no ML/adaptive logic. |

## T6 Live-Promotion-Caveat

N/A. Proposed universe uses broker-routable DWX symbols only.
