---
ea_id: QM5_10684
slug: tv-ssl-hama
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "hosixx, TrendGuard Scalper: SSL + Hama Candle with Consolidation Zones, TradingView open-source strategy, https://www.tradingview.com/script/D817LSt0/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/consolidation-filter]]"
  - "[[concepts/scalping]]"
indicators:
  - "[[indicators/ssl-channel]]"
  - "[[indicators/hama-candle]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 220
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL cited; R2 mechanical SSL/Hama/ATR-consolidation entries with TP/Hama-return exit and ~220 trades/year/symbol; R3 OHLC EMA/ATR logic testable on DWX FX/metals/indices; R4 fixed non-ML one-position rules."
---

# TradingView SSL Hama TrendGuard Scalper

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `TrendGuard Scalper: SSL + Hama Candle with Consolidation Zones`, author handle `hosixx`, open-source strategy, published 2024-10-31, https://www.tradingview.com/script/D817LSt0/

## Mechanik

### Entry
Use M15-M30 baseline first despite the source name, then test M5 only if P5b latency permits.

- Compute SSL Channel trend state.
- Compute Hama Candles from EMA transforms of open, high, low, and close plus Hama Line.
- Compute ATR-based consolidation filter; block entries during low-volatility/choppy zones.
- Long setup:
  - SSL Channel is green/uptrend.
  - Hama trend is green/uptrend.
  - Close is above the Hama Candles / Hama Line.
  - Consolidation filter is not active.
- Short setup:
  - SSL Channel is red/downtrend.
  - Hama trend is red/downtrend.
  - Close is below the Hama Candles / Hama Line.
  - Consolidation filter is not active.

### Exit
- Take profit at configured risk-to-reward level.
- Exit if price returns to the Hama Candle / Hama Line before TP.
- Forced session/weekend flat follows V5 defaults.

### Stop Loss
- Long stop below the Hama Line.
- Short stop above the Hama Line.
- P2 adds broker-safe 0.1 ATR buffer.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- ATR consolidation filter must be false.
- Closed-bar confirmation only.
- Because the source is scalping-oriented, P5b calibrated latency stress is required before live promotion.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - SSL and Hama trend alignment define direction.
- [[concepts/consolidation-filter]] - ATR-based chop filter suppresses low-quality entries.
- [[concepts/scalping]] - short-hold trend entries need latency validation.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `hosixx` are cited. |
| R2 Mechanical | PASS | Source defines SSL/Hama trend alignment, ATR consolidation block, TP/SL, and Hama-return exit. |
| R3 Data Available | PASS | Uses OHLC-derived EMA/ATR/channel logic available on DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed non-ML rules; no grid, martingale, or pyramiding. Scalping is flagged for P5b latency validation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10682 tv-keltner-zones
- QM5_10683 tv-sd-ob-break

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
