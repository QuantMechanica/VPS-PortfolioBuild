---
ea_id: QM5_11697
slug: pl-bb20-m5-scalp-d1trend
type: strategy
source_id: 53a42802-5c56-515a-af4e-2c89ce420488
sources:
  - "[[sources/paul-langer-black-book-forex-trading]]"
concepts:
  - "[[concepts/bollinger-bands]]"
  - "[[concepts/multi-timeframe]]"
  - "[[concepts/scalping]]"
  - "[[concepts/pullback-entry]]"
indicators:
  - BB(20,2)
  - SMA(200,D1)
period: M5
source_citation: "Paul Langer, 'A Scalping Strategy', in: The Black Book of Forex Trading, Alura Publishing, 2015. R1 FAIL."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; local book PDF (Paul Langer, Alura Publishing 2015) qualifies under current R1 rules — track record not required."
r2_mechanical: PASS
r2_reasoning: "BB pierce plus directional candle plus stop-entry with fixed ATR-stop, break-even, and TP provides a fully mechanical rule set."
r3_data_available: PASS
r3_reasoning: "M5 EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX are all available DWX FX symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic BB+SMA indicators with fixed SL/TP rules; no ML, adaptive parameters, or martingale; one position per magic."
pipeline_phase: G0
last_updated: 2026-05-24
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX]
expected_trades_per_year_per_symbol: 400
card_body_incomplete: true
card_body_missing: "source_citation,exit,target_symbols"
g0_approval_reasoning: "R1 PASS single source_id/book attribution; R2 PASS deterministic M5 BB pullback stop-entry with SL/BE/TP and plausible 400 trades/year/symbol; R3 PASS DWX M5 FX symbols; R4 PASS non-ML one-position rules."
---

## Quelle

Paul Langer, *A Scalping Strategy*, in: The Black Book of Forex Trading, Alura Publishing, 2015 (559219887-The-Black-Book-of-Forex-Trading.pdf), pp.64-70. URL: local PDF archive. R1 PASS under current single-source/source_id rule.

## Mechanik

**Konzept**: M5 scalping in direction of the daily trend. Bollinger Bands (20,2) on M5 identify pullback extremes. When price pierces the outer BB (lower in uptrend), a directional continuation candle triggers a stop entry. Factory: daily trend defined as Close > SMA(200) on D1.

**Daily Trend Filter**: 
- Bullish: D1 Close > SMA(200) on D1 chart
- Bearish: D1 Close < SMA(200) on D1

**Session Filter**: London and NY overlap — server time 07:00–17:00 (W. Europe Standard Time). Avoid 60 minutes before and after major red-flag news events.

**Entry (Long — in bullish daily trend)**:
1. M5 price (Low) pierces or touches the LOWER Bollinger Band — pullback into BB
2. A BULLISH M5 candle forms (Close > Open) after the pierce
3. Place BUY STOP order 1-2 pips above the HIGH of that bullish candle
4. Cancel if not triggered within 1 bar

**Entry (Short — in bearish daily trend)**: Mirror:
1. M5 High pierces UPPER Bollinger Band
2. Bearish M5 candle forms
3. Place SELL STOP 1-2 pips below the LOW of that bearish candle

**Stop Loss**: Below the recent M5 swing low for longs (lowest Low of the last 3-5 bars before entry). Factory: 2×ATR(14,M5).

**Break Even**: Move SL to entry after +10 pips.

**Exit**: Take Profit 20 pips fixed; protective SL at 2×ATR(14,M5); break-even after +10 pips. Pending stop orders expire after 1 bar if not triggered.

**Position Sizing**: RISK_FIXED = $1000 (backtest) / RISK_PERCENT = 0.5% (live).

## Target Symbols

EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX.

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | FAIL | Self-published, no verifiable track record |
| R2 Mechanical | PASS | BB + stop entry + fixed pips SL/TP — fully mechanical |
| R3 Data Available | PASS | M5 DWX data available |
| R4 ML Forbidden | PASS | Pure indicators |

## Implementation Notes for Codex (P1)

- EA runs on M5 chart
- D1 trend: `iMA(symbol,PERIOD_D1,200,0,MODE_SMA,PRICE_CLOSE)` — compare to current D1 close
- BB(20,2) on M5: `iBands(symbol,PERIOD_M5,20,0,2,PRICE_CLOSE)` — lower band buffer
- Signal: Low[1] <= BB_Lower[1] AND Close[1] > Open[1] (bullish candle after pierce)
- Buy Stop: High[1] + 1 pip; expire after 1 bar if not filled
- SL: 2×ATR(14,M5) as factory default
- Break even: After 10 pips in profit, move SL to entry
- TP: 20 pips fixed
- Session: Check server time, only trade 07:00-17:00 CET (adjust for DST)
- News filter: Skip bars within 60 minutes of red-flag events (use news calendar)
- Note: This is a high-frequency strategy — expect ~400+ signals/year/symbol

## Pipeline-Verlauf

| Phase | Status | Datum |
|-------|--------|-------|
| G0 | PENDING | 2026-05-24 |
