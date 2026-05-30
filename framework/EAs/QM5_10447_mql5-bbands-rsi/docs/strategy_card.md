---
ea_id: QM5_10447
slug: mql5-bbands-rsi
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/bollinger-band-reversion]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author; R2 PASS deterministic RSI/Bollinger sequence, local stop, band TP/breakeven with ~70 trades/year/symbol; R3 PASS EURUSD H1/DWX FX testable; R4 PASS no ML/grid/martingale."
---

# MQL5 Bollinger RSI FullDump Reversal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "FullDump - expert for MetaTrader 5", idea by Yuri, MQL5 code by Vladimir Karputov, published 2018-07-09, https://www.mql5.com/en/code/21032

## Mechanik

### Entry
- Search for a valid signal within bars 0 through `Depth of search`.
- Long setup:
  - RSI is below 30.
  - Price reaches the lower Bollinger Band.
  - Wait until a candlestick moves above the middle Bollinger Band.
- Short setup:
  - RSI is above 70.
  - Price reaches the upper Bollinger Band.
  - Wait until a candlestick moves below the middle Bollinger Band.

### Exit
- Long: take profit at the upper Bollinger Band.
- Short: take profit at the lower Bollinger Band.
- Move stop to breakeven after the opposite outer band target is reached per source management rule; in V5 this should be implemented as a deterministic breakeven transition.

### Stop Loss
- Long: below the last local low, with configured high/low indent.
- Short: above the last local high, with configured high/low indent.

### Position Sizing
- Source exposes fixed lots. V5 baseline uses fixed-risk $1,000 per backtest trade from local high/low stop distance.

### Zusätzliche Filter
- Inputs: Bollinger averaging period, RSI averaging period, high/low indent, depth of search, magic number.
- Source shows EURUSD H1 optimization example; start with EURUSD.DWX H1 and expand cross-sectionally after Q02.
- V5 default max-spread and one-position-per-magic guards.

## Concepts (was ist das für eine Strategie)
- [[concepts/mean-reversion]] - primary
- [[concepts/bollinger-band-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase URL with idea attribution, code author, and publish date. |
| R2 Mechanical | PASS | RSI/Bollinger sequence, local high/low stop, band TP, and breakeven transition are rule-based. |
| R3 Data Available | PASS | Source uses EURUSD H1; DWX FX data is available. |
| R4 ML Forbidden | PASS | No ML, no grid, no martingale, no adaptive online parameter changes. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10445_mql5-stddev-rsi]] - standard-deviation-envelope RSI reversion.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence is estimated from EURUSD H1 Bollinger/RSI reversion with a depth-of-search gate.*

