---
ea_id: QM5_1220
slug: carver-mrwings
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/extreme-forecast]]"
  - "[[concepts/trend-exhaustion]]"
indicators:
  - "[[indicators/ewmac]]"
  - "[[indicators/rolling-standard-deviation]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 25
g0_approval_reasoning: "Carver qoppac 2021 live mrwrings4 + 2020 forecast-linearity post + pysystemtrade rules/mr_wings.py R1-R4 PASS: R1 named author + qoppac URLs + open-source code URL; R2 ewmac/StdDev base + WingSigma=3 threshold gate + raw_signal=-ewmac (sign inversion) + ExitSigma=2 + forecast cap deterministic; R3 D"
---

# QM5_1220 Carver Mean Reversion In The Wings

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2021/12/my-trading-system.html
- Supplemental URL: https://qoppac.blogspot.com/2020/09/forecast-linearity-and-forecasting-mean.html
- Code URL: https://github.com/pst-group/pysystemtrade/blob/develop/systems/provided/rules/mr_wings.py
- Author: Rob Carver. The 2021 post lists `mrwrings4` in the rule table and notes mean reversion in the wings as an active non-trend family; the linked code implements it as a contrarian signal only when EWMAC is more than three rolling standard deviations from zero.

## Mechanik

Extreme-trend mean reversion rule. It remains flat for ordinary trend readings and only fades unusually large EWMAC forecasts, using the thesis that very strong slow-momentum signals can be exhausted in the distribution tails.

Suggested DWX universe for P2: GER40.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.

### Entry
- On each closed D1 bar:
  - `Lslow = 4 * Lfast`.
  - `ewmac_t = (EMA(Close, Lfast) - EMA(Close, Lslow)) / StdDev(Close changes, 25)`.
  - `wing_std_t = StdDev(ewmac, WingStdLookback)`.
  - If `abs(ewmac_t) < WingSigma * wing_std_t`, set `raw_signal = 0`.
  - Otherwise set `raw_signal = -ewmac_t`.
  - `forecast = ForecastScalar * raw_signal`.
  - cap forecast to `[-20,+20]`.
- LONG if `forecast > +EntryForecast` (large negative trend extreme).
- SHORT if `forecast < -EntryForecast` (large positive trend extreme).
- Default variant: `Lfast=4`, `Lslow=16`, `WingSigma=3`, `WingStdLookback=5000`, `EntryForecast=2`.

### Exit
- Close LONG when `forecast <= 0` or `abs(ewmac_t) < ExitSigma * wing_std_t`.
- Close SHORT when `forecast >= 0` or `abs(ewmac_t) < ExitSigma * wing_std_t`.
- Default `ExitSigma=2`.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.5`, `3.0`, `3.5` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `max(Lslow + 30, WingStdLookback)` bars for the strict Carver version.
- If DWX history is shorter, P1 may use `WingStdLookback=1250` and flag the deviation for G0/P2 review.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/extreme-forecast]] - primary
- [[concepts/trend-exhaustion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author, exact qoppac URL, and linked open-source rule implementation. |
| R2 Mechanical | PASS | EWMAC, rolling standard deviation threshold, sign inversion, entry, and exit are deterministic. |
| R3 DWX-testbar | PASS | Uses only D1 OHLC-derived price and volatility; portable to DWX FX, indices, metals, and oil. |
| R4 No ML | PASS | Fixed lookbacks and thresholds, one position per magic, no ML, no grid, no martingale. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog third batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] - same base EWMAC signal, opposite behaviour only at extremes.
- [[strategies/QM5_1209_carver-mrinasset]] - cross-sectional mean-reversion cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
