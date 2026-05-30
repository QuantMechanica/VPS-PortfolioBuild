---
ea_id: QM5_10179
slug: tv-ema-channel-rr
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL cited; R2 mechanical EMA channel cross entries with prior-bar stop, 2R target, time exit and ~90 trades/year/symbol; R3 portable to DWX FX/gold/index CFDs; R4 no ML/grid/martingale, one position per magic."
---

# TradingView EMA Channel Risk Reward

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `IU EMA Channel Strategy`, author handle `Shivam_Mandrai`, published 2024-12-15, https://www.tradingview.com/script/vvzZXG8e-IU-EMA-Channel-Strategy/

## Mechanik

### Entry
Use H1 bars, long and short.

- Compute EMA_high(100) on the high price.
- Compute EMA_low(100) on the low price.
- Long entry: close crosses above EMA_high(100).
- Short entry: close crosses below EMA_low(100).
- Do not enter if spread exceeds 15% of the planned stop distance.

### Exit
- Long stop loss: previous bar low.
- Short stop loss: previous bar high.
- Take profit: 2.0R from entry using the distance between entry and stop.
- Close any open position after 72 H1 bars if neither stop nor target was reached.

### Stop Loss
- Source stop is previous bar low/high; baseline preserves it.
- If previous-bar stop distance is less than 0.5 ATR(14), widen to 0.5 ATR(14) to avoid micro-stop noise.
- If previous-bar stop distance is greater than 3.0 ATR(14), skip the trade.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Primary DWX symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX.
- No pyramiding; ignore additional crosses while a position is open.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - trades momentum closes outside an EMA high/low channel.
- [[concepts/channel-breakout]] - channel boundaries are EMA(high) and EMA(low).

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Shivam_Mandrai` are cited. |
| R2 Mechanical | PASS | Source specifies EMA channel construction, cross-based entries, previous-bar stop, and RTR take profit. |
| R3 Data Available | PASS | Uses only OHLC EMA and prior-bar stop logic; portable to DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, pyramiding, or adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10116_tv-multi-ma-exit]] - related moving-average crossover family with a faster exit mechanism.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
