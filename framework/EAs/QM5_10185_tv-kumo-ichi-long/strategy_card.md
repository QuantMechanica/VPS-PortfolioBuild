---
ea_id: QM5_10185
slug: tv-kumo-ichi-long
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/pullback]]"
indicators:
  - "[[indicators/ichimoku-cloud]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL and author; R2 mechanical Ichimoku/EMA/ATR trailing rules with ~45 trades/yr/symbol; R3 OHLC/tick-volume indicators testable on DWX CFDs; R4 fixed non-ML one-position logic."
---

# TradingView Kumo Ichimoku Long

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `KumoTrade Ichimoku Strategy`, author handle `mata22tr`, published 2024-05-28 and updated 2024-06-08, https://www.tradingview.com/script/y3wPei2t-KumoTrade-Ichimoku-Strategy/

## Mechanik

### Entry
Use H1 bars, long-only baseline.

- Compute standard Ichimoku components:
  - Tenkan-sen = midpoint of highest high / lowest low over 9 bars.
  - Kijun-sen = midpoint of highest high / lowest low over 26 bars.
  - Senkou Span A/B form the Kumo cloud.
  - senkou_max = max(Senkou A, Senkou B), senkou_min = min(Senkou A, Senkou B).
- Bullish bias: low is above the daily EMA baseline.
- Setup memory: within the last 21 bars, Kijun-sen was above senkou_max while close was below senkou_min.
- Entry trigger can be either:
  - Tenkan-sen crosses above Kijun-sen, or
  - price crosses below Kijun-sen and then closes back above it.
- Main long entry requires close above Kumo, green Kumo, bullish bias, trigger true, high-volume filter true, and current close not inside the Kumo.
- Ultra-long entry uses the same bullish bias and trigger but allows a Kijun touch-down reversal outside the Kumo.
- One open position maximum.

### Exit
- Trailing stop is the primary exit.
- Close long if the trailing stop is hit.
- Defensive exit: close if close enters below senkou_min after entry.

### Stop Loss
- Dynamic trailing stop = highest high of last 5 bars - 3.0 * ATR(14).
- Initial stop at entry uses the same formula, capped at 2.5 * ATR(14) if the source formula is wider.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Use completed higher-timeframe daily EMA values only; no lookahead.
- Volume filter baseline: tick volume > SMA(tick volume, 20).
- DWX port targets EURJPY.DWX, GBPJPY.DWX, XAUUSD.DWX, NDX.DWX, and GER40.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - Ichimoku cloud and daily EMA bias identify bullish trend regimes.
- [[concepts/pullback]] - Kijun touch-down and Tenkan/Kijun cross re-enter after a pullback.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `mata22tr` are cited. |
| R2 Mechanical | PASS | Source gives Ichimoku components, bullish bias, 21-bar setup window, long entry conditions, and ATR trailing stop. |
| R3 Data Available | PASS | Uses OHLC, tick volume, EMA, Ichimoku, and ATR primitives available on DWX CFDs. |
| R4 ML Forbidden | PASS | Long-only fixed indicator logic, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_9360_mql5-ichi-kumo-cross]] - related Ichimoku cloud/cross family from a different source.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
