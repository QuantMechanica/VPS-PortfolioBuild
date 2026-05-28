---
ea_id: QM5_10194
slug: tv-st-rsi-pos
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/rsi]]"
  - "[[indicators/adx]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL cited; R2 mechanical Supertrend/RSI/ADX entry and Supertrend-or-RSI exit with ~45 trades/year/symbol; R3 ports to DWX index/gold CFDs; R4 no ML/grid/martingale and one-position."
---

# TradingView Supertrend RSI Positional

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Supertrend + RSI Positional Strategy`, author handle `subrajitmishra`, published 2026-05-18, https://www.tradingview.com/script/7iuBqJxj-Supertrend-RSI-Positional-Strategy/

## Mechanik

### Entry
Use H1/H4 bars in baseline.

- Long-only.
- Supertrend state is bullish on confirmed bar close.
- RSI is above bullish threshold; source default is 50.
- Optional ADX filter enabled in baseline: ADX above 20.
- Enter only when flat; no pyramiding.

### Exit
- Baseline uses the source's faster `Supertrend OR RSI` exit mode.
- Close long when Supertrend turns bearish or RSI falls below the bullish threshold.
- P3 may test stricter source modes: Supertrend-only, RSI-only, or Supertrend-and-RSI.

### Stop Loss
- Protective stop: 2.0 ATR(14) below entry until P3 refines.
- Source page does not define a price stop; this is a V5 protective default.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Target Symbols
NDX.DWX, WS30.DWX, DAX.DWX, XAUUSD.DWX.

### Zusatzliche Filter
- Confirmed bar closes only.
- Do not trade on M1/M5 scalping timeframes; source explicitly frames the idea as 1H+ positional.
- SP500.DWX optional backtest analog: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/momentum]] - RSI/ADX confirmation

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `subrajitmishra` are cited. |
| R2 Mechanical | PASS | Source defines Supertrend, RSI threshold, optional ADX entry filter, selectable exit modes, one-position behavior, and confirmed-bar evaluation. |
| R3 Data Available | PASS | Supertrend/RSI/ADX OHLC-derived logic ports to DWX index CFDs, gold, and FX. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, pyramiding, or adaptive live parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10152_tv-nq-supertrend-macd]] - related Supertrend trend-following family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

