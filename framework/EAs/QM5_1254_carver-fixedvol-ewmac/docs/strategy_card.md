---
ea_id: QM5_1254
slug: carver-fixedvol-ewmac
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-estimation]]"
  - "[[concepts/forecast-scaling]]"
indicators:
  - "[[indicators/ewmac]]"
  - "[[indicators/fixed-volatility]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 10
g0_approval_reasoning: "R1-R4 PASS: Rob Carver qoppac 2018-07 vol-targeting + 2020-09 forecast-linearity + 2015-09 EWMAC URLs; deterministic EWMAC(64/256) scaled by 1500d median-abs-return fixed_vol (frozen monthly), capped forecast [-20,+20] thresholded; DWX FX/indices/metals/oil; fixed-window vol estimate (NOT adaptive l"
---

# QM5_1254 Carver Fixed-Volatility EWMAC

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac.blogspot.com/2018/07/vol-targeting-and-trend-following.html
- Supplemental URL: qoppac.blogspot.com/2020/09/forecast-linearity-and-forecasting-mean.html
- Supplemental URL: qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
- Author: Rob Carver. The 2018 and 2020 posts discuss how volatility targeting/estimation changes trend-following skew and forecast behaviour; the 2015 post supplies the base EWMAC code.

## Mechanik

EWMAC trend following where forecast scaling uses a slow fixed volatility estimate instead of rapidly changing current volatility. This intentionally tests Carver's question of whether volatility targeting changes the trend-following payoff shape.

### Entry
- On each closed D1 bar:
  - Compute raw EWMAC: `EMA(close,64) - EMA(close,256)`.
  - Compute `fixed_vol = Median(abs(daily_return), FixedVolLookbackDays) * 16`.
  - Default `FixedVolLookbackDays = 1500`.
  - Forecast = raw EWMAC divided by `fixed_vol * close`, scaled to average absolute forecast target `10`, then capped to `[-20,+20]`.
- LONG if forecast > `+4`.
- SHORT if forecast < `-4`.

### Exit
- Close LONG when forecast <= `0`.
- Close SHORT when forecast >= `0`.
- Flip only on a later D1 close with opposite threshold.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.5` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Position size is still based on current ATR stop distance; fixed volatility affects forecast generation, not risk cap.
- One position per symbol/magic.

### Zusätzliche Filter
- Require at least `FixedVolLookbackDays + 256` D1 bars.
- Freeze `fixed_vol` monthly to avoid daily noise in signal scaling.
- Skip new entries when current spread exceeds `2 * MedianSpread(20D)`.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/volatility-estimation]] - primary
- [[concepts/forecast-scaling]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs for volatility targeting/forecast behaviour and EWMAC implementation. |
| R2 Mechanical | PASS | EWMAC, fixed volatility estimate, thresholds, exits, and stop are deterministic. |
| R3 DWX-testbar | PASS | Uses DWX daily OHLC returns and ATR; portable to FX, indices, metals, and oil CFDs. |
| R4 No ML | PASS | Fixed-window volatility estimate and fixed thresholds; no ML, adaptive PnL parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog fifth batch, PENDING. Source context says this is a comparison variant rather than Carver's preferred live implementation.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] - current-volatility EWMAC base rule.
- [[strategies/QM5_1228_carver-volatten-ewmac]] - volatility-percentile attenuated cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*

