---
ea_id: QM5_10186
slug: tv-pivot-time-break
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/session-filter]]"
indicators:
  - "[[indicators/pivot-points]]"
  - "[[indicators/moving-average]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 100
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL and author; R2 mechanical pivot breakout/session/MA rules with ~100 trades/yr/symbol; R3 OHLC/ATR/session rules portable to DWX CFDs; R4 fixed non-ML one-position logic."
---

# TradingView Pivot Timefilter Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Breakouts With Timefilter Strategy [LuciTech]`, author handle `TradesLuci`, published 2025-03-01, https://www.tradingview.com/script/k8xoF70l-Breakouts-With-Timefilter-Strategy-LuciTech/

## Mechanik

### Entry
Use M15 or H1 bars, long and short.

- Detect pivot highs/lows using a configurable left/right pivot length.
- Active pivot high becomes long breakout level after confirmation.
- Active pivot low becomes short breakout level after confirmation.
- Long entry: close crosses above active pivot high.
- Short entry: close crosses below active pivot low.
- Moving-average filter:
  - Longs allowed only when close is above selected MA.
  - Shorts allowed only when close is below selected MA.
- Time filter: allow entries only during configured liquid session.
- One open position maximum; close any opposite exposure before reversing.

### Exit
- Attach stop loss and take profit at entry.
- Take profit = risk distance * RR multiplier.
- Close at session end if still open.

### Stop Loss
- Baseline stop type: ATR stop.
- Stop distance = ATR(14) * 1.5 using RMA smoothing.
- P3 may test prior-candle high/low or fixed-point stop variants because the source explicitly supports them.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number. Source percent-equity sizing is not used in P2.

### Zusatzliche Filter
- Baseline MA = EMA(100); P3 may test SMA/EMA/WMA/VWMA/HMA as source variants.
- Session baseline for indices: 09:30-16:00 New York; for FX: London/New York overlap.
- Spread must be <= 15% of stop distance.
- DWX port targets NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, and EURUSD.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - close beyond confirmed pivot high/low.
- [[concepts/session-filter]] - source limits execution to selected active trading windows.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `TradesLuci` are cited. |
| R2 Mechanical | PASS | Source specifies pivot breakout entries, ATR/prior/fixed stops, RR target, MA filter, and time filter. |
| R3 Data Available | PASS | Uses OHLC, moving averages, ATR, and clock/session fields; portable to DWX FX, gold, oil, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, or adaptive live parameters; source percent-risk sizing is replaced by V5 fixed risk. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10184_tv-atr-zigzag-break]] - related pivot breakout with ATR-ZigZag pivot construction instead of left/right pivots.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
