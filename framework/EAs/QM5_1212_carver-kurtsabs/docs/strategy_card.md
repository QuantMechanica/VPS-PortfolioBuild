---
ea_id: QM5_1212
slug: carver-kurtsabs
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 20
---

# QM5_1212 Carver Absolute Kurtosis-Conditioned Skew

## Quelle
- Source: Rob Carver blog
- Primary URL: qoppac.blogspot.com/2020/01/skew-and-kurtosis-as-trading-rules.html
- Supplemental URL: qoppac.blogspot.com/2021/12/my-trading-system.html
- Author: Rob Carver.

## Mechanik

Higher-moment rule that trades skew only when the distribution also has meaningful kurtosis. The intent is to capture asymmetric tail behaviour while avoiding redundant skew variants.

Suggested DWX universe for P2: GER40.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX.

### Entry
- On each closed D1 bar:
  - `r_t = log(Close_t / Close_(t-1))`.
  - `skew_t = Skewness(r, Lookback)`.
  - `kurt_t = ExcessKurtosis(r, Lookback)`.
  - `skew_signal = skew_t - BaselineSkew`.
  - `kurt_gate = kurt_t - BaselineKurtosis`.
  - `raw_signal = skew_signal * max(kurt_gate, 0)`.
  - `forecast = ForecastScalar * raw_signal / RollingAbsMedian(raw_signal, 252)`.
  - Cap forecast to `[-20,+20]`.
- LONG if `forecast > +EntryForecast`.
- SHORT if `forecast < -EntryForecast`.
- Default variant: `Lookback=180`, `BaselineSkew=0`, `BaselineKurtosis=0`, `EntryForecast=2`.
- P3 sweep Carver variants: `Lookback in {180,365}`; optional exploratory `{30,90}` only if trade count is too low.

### Exit
- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Exit immediately if `kurt_gate <= 0` for `ExitConfirmBars=3` consecutive closed bars.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.5`, `3.0`, `3.5` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `Lookback + 252` bars before trading.
- Skip when rolling absolute median raw signal is zero or invalid.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.

## R1-R4 Bewertung
- R1 Source-Link: PASS
- R2 Mechanical: PASS
- R3 DWX-testbar: PASS
- R4 No ML: PASS

## R3 Live-Promotion-Caveat
N/A, proposed universe uses broker-routable DWX symbols only.
