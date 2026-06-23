---
ea_id: QM5_1208
slug: carver-normmom
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
  - "[[concepts/volatility-normalisation]]"
indicators:
  - "[[indicators/normalised-return]]"
  - "[[indicators/ewmac]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named author Rob Carver with exact qoppac blog URLs for rule definition and live-system listing."
r2_mechanical: PASS
r2_reasoning: "Normalised-return EWMAC formula, forecast caps, and entry/exit thresholds are fully deterministic."
r3_data_available: PASS
r3_reasoning: "Proposed universe uses only broker-routable DWX FX, index, and metals symbols; no SP500.DWX dependency."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed lookbacks and caps, one position per magic, no ML, no online learning, no martingale."
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 180
g0_approval_reasoning: "R1 PASS qoppac URLs and named author; R2 PASS deterministic normalized-return EWMAC entry/exit; R3 PASS portable to DWX FX/indices/metals; R4 PASS fixed params no ML/adaptive/grid/martingale."
---

# QM5_1208 Carver Normalised Momentum

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2017/06/some-more-trading-rules.html
- Supplemental URL: https://qoppac.blogspot.com/2021/12/my-trading-system.html
- Author: Rob Carver. The 2017 post defines cumulative normalised returns and applies EWMAC to the resulting series; the 2021 live-system post lists `normmom` variants with non-zero weights.

## Mechanik

Trend rule that first converts price into a cumulative series of volatility-normalised daily returns, then applies the usual EWMAC trend filter to that transformed series. The thesis is that normalising returns reduces cross-instrument noise and gives the trend filter a cleaner input than raw price.

Suggested DWX universe for P2: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD.

### Entry
- On each closed D1 bar:
  - `ret_t = Close_t - Close_(t-1)`.
  - `sigma_t = StdDev(ret, VolLookback)`; default `VolLookback=25`.
  - `norm_ret_t = clamp(ret_t / sigma_t, -6.0, +6.0)`.
  - `norm_price_t = cumulative_sum(norm_ret_t)`.
  - `raw = EMA(norm_price, Fast) - EMA(norm_price, Slow)`.
  - `forecast = ForecastScalar(Fast,Slow) * raw / StdDev(norm_price changes, VolLookback)`.
  - cap forecast to `[-20,+20]`.
- LONG if `forecast > +EntryForecast`.
- SHORT if `forecast < -EntryForecast`.
- Default variant: `Fast=16`, `Slow=64`, `EntryForecast=2`.
- P3 sweep speeds from Carver's 2021 live weights: `Fast in {2,4,8,16,32,64}`, `Slow=4*Fast`.

### Exit
- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Flip only on a later closed bar with opposite threshold.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.0` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Skip entries when `sigma_t <= 0` or fewer than `Slow + VolLookback` bars are available.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.
- News filter hook for high-impact events.

## Concepts
- [[concepts/trend-following]] — primary
- [[concepts/momentum]] — primary
- [[concepts/volatility-normalisation]] — secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs for the rule definition and live-rule listing. |
| R2 Mechanical | PASS | Formula for normalised returns, cumulative normalised price, EWMAC filter, caps, and speed variants is deterministic. |
| R3 DWX-testbar | PASS | Uses only daily OHLC-derived returns and volatility; portable to DWX FX, indices, metals, and oil. |
| R4 No ML | PASS | Fixed lookbacks, fixed caps, one position per magic, no ML, no online learning, no martingale. |

## R3 — T6 Live-Promotion-Caveat
N/A — proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 — drafted from Rob Carver blog second batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] — raw-price EWMAC trend cousin.
- [[strategies/QM5_1069_carver-assettrend]] — asset-class aggregate momentum cousin.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
