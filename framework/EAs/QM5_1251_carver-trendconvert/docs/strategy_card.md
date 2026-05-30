---
ea_id: QM5_1251
slug: carver-trendconvert
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/asset-class-filter]]"
  - "[[concepts/forecast-scaling]]"
indicators:
  - "[[indicators/ewmac]]"
  - "[[indicators/rolling-sharpe]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 8
g0_approval_reasoning: "R1-R4 PASS: Rob Carver qoppac 2026-01 trend-conversion + 2015-09 EWMAC URLs; deterministic asset-class median ConversionSR gate + EWMAC(64/256) forecast thresholds; DWX FX/indices/metals/energy; fixed-window historical filter (NOT online learning), one position per magic, no grid/martingale."
---

# QM5_1251 Carver Trend-Converter Asset Filter

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac-url:qoppac.blogspot.com/2026/01/are-markets-that-are-good-for-trend.html
- Supplemental URL: qoppac-url:qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
- Author: Rob Carver. The 2026 post studies whether assets that have historically converted raw return/carry/vol characteristics into trend-following performance should be filtered or downweighted; the 2015 post supplies the EWMAC formula.

## Mechanik

Slow EWMAC trend following with an asset-class trend-conversion gate. The EA only opens new trend trades when the symbol's asset-class cohort has a positive historical trend-conversion score.

### Entry
- Monthly, per configured asset class:
  - Compute daily EWMAC forecast for each member symbol with default `64/256`.
  - Compute rolling `ConversionSR = Sharpe(EWMAC_forecast_lagged * next_day_return, ConversionLookbackDays)`.
  - Default `ConversionLookbackDays = 1500`.
  - Asset-class score = median `ConversionSR` across current members with enough history.
- On each closed D1 bar for each symbol:
  - Trade only if its asset-class score is `> MinConversionSR`.
  - Default `MinConversionSR = 0.05`.
  - Compute symbol EWMAC forecast `forecast = EMA(close,64) - EMA(close,256)`, volatility-normalised and capped to `[-20,+20]`.
- LONG if `forecast > +4`.
- SHORT if `forecast < -4`.

### Exit
- Close LONG when `forecast <= 0` or asset-class score falls below `0`.
- Close SHORT when `forecast >= 0` or asset-class score falls below `0`.
- Recheck the asset-class gate monthly; signal exits still evaluate daily.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `3.0`, `3.5` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `ConversionLookbackDays + 256` bars.
- Valid DWX groups: FX, indices, metals, energy. If a group has fewer than `3` members, use symbol-level conversion score instead of asset-class median.
- Skip new entries when current spread exceeds `2 * MedianSpread(20D)`.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/asset-class-filter]] - primary
- [[concepts/forecast-scaling]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs for the 2026 trend-conversion discussion and EWMAC implementation. |
| R2 Mechanical | PASS | Asset-class conversion score, monthly gate, EWMAC thresholds, and exits are deterministic. |
| R3 DWX-testbar | PASS | Uses DWX daily OHLC returns and predefined DWX asset-class groups. |
| R4 No ML | PASS | Rolling historical score is a fixed filter, not online parameter learning; one position per magic; no grid or martingale. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog fifth batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] - unfiltered base trend rule.
- [[strategies/QM5_1232_carver-fastmom-cost]] - cost-conditioned trend-family cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*

