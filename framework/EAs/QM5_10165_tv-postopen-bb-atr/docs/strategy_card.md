---
ea_id: QM5_10165
slug: tv-postopen-bb-atr
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/volatility-expansion]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic BB/EMA/RSI/ADX resistance breakout with ATR stop/target and ~120 trades/year/symbol; R3 OHLC/session logic portable to DWX FX, metals, indices; R4 no ML/grid/martingale."
---

# TradingView Post Open BB ATR Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Post-Open Long Strategy with ATR-based Stop Loss and Take Profit`, author handle `MatteoRizzitelli`, published 2024-09-19, https://www.tradingview.com/script/wApzruR3/

## Mechanik

### Entry
Use M5 or M15 bars, long-only.

- Trade only during German open window 08:00-12:00 or US open window 15:30-19:00 local exchange/reference time.
- Identify lateralization with Bollinger Bands length 14, standard deviation 1.5, and price near the BB basis/SMA.
- Require close above EMA(10) and EMA(200).
- Require RSI(7) > 30.
- Require ADX(7, smoothing 7) > 10.
- Identify resistance from the highs of the last 20 candles with at least two touches.
- Long entry: price breaks above the identified resistance while the filters above are true.
- Source includes a negative "panic candle" condition; baseline interprets this as requiring the setup candle immediately before breakout to close red, not the breakout candle itself.
- Reject entry if the two previous candles are both bearish.

### Exit
- Take profit at entry + 4.0 ATR(14).
- Stop loss at entry - 2.0 ATR(14).
- Close at the end of the selected post-open trading window if neither stop nor target was reached.

### Stop Loss
- Dynamic stop loss: 2.0 ATR(14) below entry.
- Do not widen stop after entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Long-only baseline: prioritize NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, EURUSD.DWX.
- Spread must be <= 15% of ATR stop distance.
- No overnight holding.

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - resistance breakout after compression
- [[concepts/volatility-expansion]] - BB lateralization into open-session expansion

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `MatteoRizzitelli` are cited. |
| R2 Mechanical | PASS | Source specifies BB/EMA/RSI/ADX filters, resistance-break entry, trading windows, ATR stop, and ATR target. |
| R3 Data Available | PASS | Uses OHLC-derived indicators and sessions; ports to DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, or live adaptive parameters. ATR stop/target are fixed-form volatility rules. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_9984_tv-bb-outside-candle-scalping]] - related Bollinger Band volatility setup with different entry/exit mechanics.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
