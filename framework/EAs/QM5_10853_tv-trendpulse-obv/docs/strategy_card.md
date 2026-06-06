---
ea_id: QM5_10853
slug: tv-trendpulse-obv
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "ADXAE, Trend Pulse OBV, TradingView open-source strategy, Apr 19, https://www.tradingview.com/script/yyrhhzLE-Trend-Pulse-OBV/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
  - "[[concepts/volume-confirmation]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/obv]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-22
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 channel breakout plus OBV/regime exits/ATR stop with ~30 trades/year/symbol; R3 DWX OHLC/tick-volume symbols testable; R4 fixed non-ML one-position rules."
---

# TradingView Trend Pulse OBV Breakout

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Trend Pulse OBV`, author handle `ADXAE`, open-source strategy, accessed 2026-05-22, page shows Apr 19, https://www.tradingview.com/script/yyrhhzLE-Trend-Pulse-OBV/

## Mechanik

### Entry
Use D1/H4 baseline. Long-only source logic:

- Build Trend Pulse Channel midline using cascaded EMA filtering of source price.
- Build upper channel band from filtered true range multiplied by range factor.
- Compute OBV and OBV EMA.
- Compute regime EMA.
- Enter long when close crosses above the Trend Pulse upper band.
- Require OBV > OBV EMA.
- Require close > regime EMA.
- Require date/session window active if enabled; P2 keeps all dates active.

### Exit
- Close if price closes below Trend Pulse midline.
- Close if price closes below regime EMA.
- Close if ATR stop is hit.

### Stop Loss
- Initial stop = entry - ATR(14) * stop multiplier using prior-bar ATR.
- Baseline multiplier = 2.0 if source code default is unavailable from visible text.
- V5 spread guard: skip if spread > 15% of stop distance.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- OBV uses tick volume on DWX CFDs; mark any weak tick-volume behavior during P2/P3.
- Optional zero-lag preprocessing remains disabled in P2 unless source code confirms a fixed non-repainting implementation.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - only buys above a broader regime EMA.
- [[concepts/breakout]] - entry is an upper-channel breakout.
- [[concepts/volume-confirmation]] - OBV must confirm the breakout.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `ADXAE` are cited. |
| R2 Mechanical | PASS | Source gives channel breakout entry, OBV confirmation, regime filter, midline/regime exits, ATR stop, and input categories. |
| R3 Data Available | PASS | EMA-style channels, true range, OBV/tick volume, ATR, and OHLC are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed channel/OBV/EMA/ATR rules, no ML, no grid, no martingale, one-position compatible. |

## R3
Primary P2 basket: NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, EURUSD.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy is a long-only breakout strategy for daily stocks and crypto charts.
- Source says entry requires price crossing above the Trend Pulse upper band, OBV above its EMA, and bullish regime filter.
- Source says exits occur below the channel midline, below the regime EMA, or at the ATR stop.
- Source says the channel uses cascaded EMA filtering and filtered true range.

## Parameters To Test
- Timeframe: H4, D1.
- Trend Pulse period: 20, 34, 50.
- Range factor: 1.5, 2.0, 2.5.
- Regime EMA: 100, 200.
- OBV EMA length: 20, 34, 50.
- ATR stop: 1.5, 2.0, 2.5.

## Initial Risk Profile
Low-to-medium cadence long-only channel breakout. Main risk is that CFD tick volume may not preserve the source's stock/crypto OBV confirmation edge.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView mechanical strategy source.

## Verwandte Strategien
- QM5_10846 tv-growth-bo
- QM5_10844 tv-trend-pb-rsi

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
