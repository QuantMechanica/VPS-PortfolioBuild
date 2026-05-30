---
ea_id: QM5_1210
slug: carver-skewabs
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 20
---

# QM5_1210 Carver Absolute Skew Rule

## Quelle

- Source: Rob Carver blog.
- Primary URL: qoppac.blogspot.com/2020/01/skew-and-kurtosis-as-trading-rules.html
- Supplemental URL: qoppac.blogspot.com/2021/12/my-trading-system.html

## Mechanik

Slow absolute skew rule. It measures the rolling skew of daily returns for a symbol and trades in the direction implied by the sign of skew after subtracting a fixed long-run baseline.

### Entry

- On each closed D1 bar:
- `r_t = log(Close_t / Close_(t-1))`.
- `skew_t = Skewness(r, Lookback)`.
- `signal = skew_t - BaselineSkew`.
- `forecast = ForecastScalar * signal / RollingAbsMedian(signal, 252)`.
- Cap forecast to `[-20,+20]`.
- LONG if `forecast > +EntryForecast`.
- SHORT if `forecast < -EntryForecast`.
- Default variant: `Lookback=365`, `BaselineSkew=0`, `EntryForecast=2`.
- P3 sweep Carver variants: `Lookback in {180,365}` first; optional exploratory `{90}` if trade count is too low.

### Exit

- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Flip only on a later closed bar with opposite threshold.

### Stop Loss

- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.5`, `3.0`, `3.5` ATR.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter

- Require at least `Lookback + 252` bars before trading.
- Skip when rolling absolute median signal is zero or invalid.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.

## R1-R4 Bewertung

| Kriterium | Status |
|-----------|--------|
| R1 Source-Link | PASS |
| R2 Mechanical | PASS |
| R3 DWX-testbar | PASS |
| R4 No ML | PASS |

## R3 Live-Promotion-Caveat

N/A. Proposed universe uses broker-routable DWX symbols only.
