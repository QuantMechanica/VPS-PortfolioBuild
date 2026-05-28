---
ea_id: QM5_10163
slug: tv-rsi-macd-long
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/macd]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-21
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 deterministic RSI/MACD entry/exit plus TP/SL with about 70 trades/year/symbol; R3 OHLC logic portable to DWX CFDs with SP500 T6 caveat; R4 no ML/grid/martingale."
---

# TradingView RSI MACD Long Only

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `RSI + MACD Long-Only Strategy`, author handle `agrothe`, published 2025-08-08, https://www.tradingview.com/script/m99D8MgQ-RSI-MACD-Long-Only-Strategy/

## Mechanik

### Entry
Use H1 baseline bars, long-only.

- Calculate RSI with configurable midline; baseline RSI(14), midline 50.
- Calculate standard MACD; baseline 12/26/9.
- Long entry condition A: RSI crosses above 50 while MACD > signal line and, if enabled, MACD > 0.
- Long entry condition B: MACD crosses above signal line while RSI >= 50.
- Optional trend filter: require close > EMA(200) in baseline.
- Optional oversold-context filter: allow entries only within 20 bars after RSI dipped below 30; baseline disabled for first P2.

### Exit
- Close long when RSI crosses below 50.
- Close long when MACD crosses below signal line and MACD histogram <= 0.
- Protective TP/SL exits may trigger first.

### Stop Loss
- Source risk defaults: TP 3.0%, SL 1.5% from average entry price.
- Baseline uses the source percent levels, with ATR sanity cap so stop distance is not below 1.0 ATR(14) on high-spread symbols.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Long-only baseline fits index CFDs and metals better than symmetric FX; test NDX.DWX, SP500.DWX backtest-only, XAUUSD.DWX, and major FX as optional long-only variants.
- State gate must require flat position before a fresh entry.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum]] - primary
- [[concepts/trend-following]] - optional EMA200 trend filter

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `agrothe` are cited. |
| R2 Mechanical | PASS | Source defines RSI/MACD entries, momentum-fade exits, optional EMA/oversold filters, and TP/SL levels. |
| R3 Data Available | PASS | OHLC-derived RSI/MACD/EMA logic ports to DWX FX, gold, and index CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, pyramiding, or adaptive online parameters; source explicitly describes long-only single-position state management. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10118_tv-rsi-trend-cont]] - related RSI/MACD/Stochastic continuation rule.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
