---
ea_id: QM5_10187
slug: tv-vwap-rsi-scalp
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/scalping]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/session-filter]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/rsi]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS exact TradingView URL/author cited; R2 PASS mechanical VWAP/RSI/EMA/session entries with ATR exits and ~180 trades/year/symbol; R3 PASS portable to DWX CFDs; R4 PASS fixed rules, no ML/grid/martingale, one position."
---

# TradingView VWAP RSI Scalper

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `VWAP-RSI Scalper FINAL v1`, author handle `michaelriggs`, published 2025-08-07, https://www.tradingview.com/script/S9hY3huK-VWAP-RSI-Scalper-FINAL-v1/

## Mechanik

### Entry
Use M5 or M15 bars, long and short.

- Compute session VWAP.
- Compute RSI(3).
- Compute EMA trend filter; baseline EMA(50).
- Long setup:
  - RSI(3) is oversold (baseline <= 20).
  - close > session VWAP.
  - close > EMA(50).
  - current time is inside allowed session hours.
- Short setup:
  - RSI(3) is overbought (baseline >= 80).
  - close < session VWAP.
  - close < EMA(50).
  - current time is inside allowed session hours.
- Maximum 3 trades per day per symbol.
- One open position maximum.

### Exit
- Attach bracket immediately after entry.
- Take profit = 2.0 * ATR(14) from entry.
- Stop loss = 1.0 * ATR(14) from entry.
- Close all positions at session end.

### Stop Loss
- ATR(14) stop, fixed at entry.
- No breakeven or trailing stop in baseline.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Source defaults to US cash-session style liquidity; DWX baseline uses index cash-session analogs and London/New York overlap for FX.
- Spread must be <= 15% of ATR stop distance.
- DWX port targets NDX.DWX, WS30.DWX, XAUUSD.DWX, XTIUSD.DWX, and EURUSD.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/scalping]] - short-timeframe intraday entries with fixed ATR bracket.
- [[concepts/mean-reversion]] - RSI(3) exhaustion inside VWAP/EMA directional bias.
- [[concepts/session-filter]] - source only trades liquid hours and caps daily trade count.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `michaelriggs` are cited. |
| R2 Mechanical | PASS | Source specifies RSI, VWAP, EMA, session, ATR stop/target, and max-trades-per-day mechanics. |
| R3 Data Available | PASS | Uses OHLC, tick volume/session VWAP, RSI, EMA, ATR, and clock fields available for DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator thresholds, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10178_tv-vwap-mr-forex]] - VWAP mean-reversion family, slower and range-band focused.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
