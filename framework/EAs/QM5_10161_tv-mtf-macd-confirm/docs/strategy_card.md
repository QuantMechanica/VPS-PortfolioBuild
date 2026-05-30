---
ea_id: QM5_10161
slug: tv-mtf-macd-confirm
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/macd]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 MACD MTF entry/exit/stop rules mechanical with expected 90 trades/year/symbol; R3 OHLC MACD ports to DWX CFDs; R4 no ML/grid/martingale and one-position compatible."
---

# TradingView Multi-Timeframe MACD Confirm

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Multi-Timeframe MACD Strategy ver 1.0`, author handle `fenyesk`, published 2025-03-14, https://www.tradingview.com/script/WqzrfL2Q-Multi-Timeframe-MACD-Strategy-ver-1-0/

## Mechanik

### Entry
Use H1 bars with H4 as the higher-timeframe confirmation in baseline.

- Calculate standard MACD on the chart timeframe and the higher timeframe.
- Long: current-timeframe MACD line crosses above signal line and higher-timeframe MACD state is bullish.
- Short: current-timeframe MACD line crosses below signal line and higher-timeframe MACD state is bearish.
- Baseline uses the source's `Crossover` mode only. Do not combine crossover and zero-cross in the first build; that belongs in P3 parameter sweep.

### Exit
- Close long when current-timeframe MACD line crosses below signal line.
- Close short when current-timeframe MACD line crosses above signal line.
- Optional source trailing stop may be tested in P3, but baseline uses signal reversal plus protective fixed risk stop.

### Stop Loss
- Protective stop: 2.0 ATR(14) from entry until P3 refines the stop.
- If source trailing stop mode is enabled in a later sweep, use fixed percent distance from entry and trail only in the favorable direction.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Target Symbols
EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX.

### Zusatzliche Filter
- Higher timeframe data must use completed bars only; no lookahead.
- Trade both directions only on symbols where shorting is native in DWX.
- Baseline ignores visual MACD plots; only rule states drive execution.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/momentum]] - MACD confirmation across timeframes

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `fenyesk` are cited. |
| R2 Mechanical | PASS | Source defines MACD calculations, crossover/zero-cross entry modes, higher-timeframe agreement, reversal exits, and optional trailing stop. |
| R3 Data Available | PASS | MACD OHLC-derived logic ports directly to DWX FX, gold, oil, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, or performance-adaptive parameters. Higher-timeframe confirmation is fixed-form indicator logic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10152_tv-nq-supertrend-macd]] - related MACD trend confirmation with extra Supertrend/RSI gates.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
