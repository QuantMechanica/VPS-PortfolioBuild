---
ea_id: QM5_1218
slug: carver-relmomentum
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/momentum]]"
  - "[[concepts/volatility-normalisation]]"
indicators:
  - "[[indicators/normalised-return]]"
  - "[[indicators/asset-class-relative-price]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 90
g0_approval_reasoning: "R1 named Rob Carver blog plus code URL; R2 deterministic relative momentum entry/exit rules; R3 testable on DWX FX/index groups; R4 fixed parameters, bounded slots, one position per magic, no ML/martingale."
---

# QM5_1218 Carver Relative Momentum Within Asset Class

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac.blogspot.com/2021/12/my-trading-system.html
- Supplemental URL: qoppac.blogspot.com/2017/06/some-more-trading-rules.html
- Code URL: github.com/pst-group/pysystemtrade/blob/develop/systems/provided/rules/rel_mom.py
- Author: Rob Carver. The 2021 post lists `relmomentum10/20/40/80` in the live rule set and links the code; in a 2023 comment Carver clarifies it is cross-sectional momentum implemented using the older relative/mean-reversion machinery with the sign changed.

## Mechanik

Cross-sectional momentum rule within a DWX asset group. The rule compares each instrument's cumulative volatility-normalised price to the asset-class normalised price and buys persistent outperformers while selling persistent underperformers.

Suggested DWX universe for P2: FX majors group (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX) and index group (GER40.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX).

### Entry
- On each closed D1 bar for every symbol in its asset group:
  - `norm_price_i = cumulative_sum((Close_i - Close_i[-1]) / StdDev(Close_i changes, 25))`.
  - `asset_norm_price = equal_weight_average(norm_price_i for all valid group symbols)`.
  - `outperformance_i = norm_price_i - asset_norm_price`.
  - `avg_outperformance = (outperformance_i - outperformance_i[horizon bars ago]) / horizon`.
  - `forecast_i = EMA(avg_outperformance, max(2, horizon/4)) * ForecastScalar(horizon)`.
  - cap forecast to `[-20,+20]`.
- LONG if `forecast_i > +EntryForecast`.
- SHORT if `forecast_i < -EntryForecast`.
- Default variant: `horizon=40`, `EntryForecast=2`.
- P3 sweep Carver variants: `horizon in {10,20,40,80}`.

### Exit
- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Flip only on a later closed D1 bar with opposite threshold.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.0` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.
- Cross-sectional slot cap: at most `2` long and `2` short positions per asset group.

### Zusätzliche Filter
- Require at least `horizon + 30` bars for every group member used in the average.
- Do not trade a group unless at least `4` symbols have valid data.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.

## Concepts
- [[concepts/cross-sectional-momentum]] - primary
- [[concepts/momentum]] - primary
- [[concepts/volatility-normalisation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author, exact qoppac URL, and linked open-source rule implementation. |
| R2 Mechanical | PASS | Outperformance versus asset-class normalised price, horizon averaging, EWMA smoothing, thresholds, and exits are deterministic. |
| R3 DWX-testbar | PASS | Uses only daily close-derived returns and group averages; portable to DWX FX and index baskets. |
| R4 No ML | PASS | Fixed lookbacks, fixed caps, bounded cross-sectional slots, one position per magic, no ML or martingale. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog third batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1209_carver-mrinasset]] - opposite-sign relative mean-reversion cousin.
- [[strategies/QM5_1208_carver-normmom]] - time-series normalised momentum cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
