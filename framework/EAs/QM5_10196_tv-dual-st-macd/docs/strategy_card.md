---
ea_id: QM5_10196
slug: tv-dual-st-macd
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/macd]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 55
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL cited; R2 mechanical dual-Supertrend/MACD entries and symmetric exits with ~55 trades/year/symbol; R3 ports to DWX FX/index/gold CFDs; R4 no ML/grid/martingale and one-position."
---

# TradingView Dual Supertrend MACD

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Dual-Supertrend with MACD - Strategy [presentTrading]`, author handle `PresentTrading`, published 2023-08-30, https://www.tradingview.com/script/zFKRj4Gi-Dual-Supertrend-with-MACD-Strategy-presentTrading/

## Mechanik

### Entry
Use H4 bars in baseline, matching the source's trend-timeframe framing.

- Calculate Supertrend 1 with ATR period 10 and factor 3.0.
- Calculate Supertrend 2 with ATR period 20 and factor 5.0.
- Calculate MACD with 12/26/9 settings.
- Long: both Supertrend indicators are bullish and MACD histogram is above zero.
- Short: both Supertrend indicators are bearish and MACD histogram is below zero.
- Baseline trades both directions where the DWX symbol supports it.

### Exit
- Close long when either Supertrend turns bearish or MACD histogram falls below zero.
- Close short when either Supertrend turns bullish or MACD histogram rises above zero.

### Stop Loss
- Protective stop: 2.0 ATR(14) from entry until P3 refines.
- Source emphasizes signal exits and automated risk settings but does not specify a fixed price stop in the public text.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Target Symbols
BTC source examples port to EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX, NDX.DWX.

### Zusatzliche Filter
- Closed-bar evaluation only.
- Use the source defaults for both Supertrend engines and MACD in P2; broader parameter adaptation belongs only in P3 sweeps.
- Optional SP500.DWX backtest analog: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/momentum]] - MACD histogram confirmation

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `PresentTrading` are cited. |
| R2 Mechanical | PASS | Source defines dual-Supertrend and MACD histogram entries, symmetric exits, default parameters, and trade-direction mode. |
| R3 Data Available | PASS | OHLC-derived Supertrend/MACD logic ports from crypto examples to DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, pyramiding, or live performance-adaptive parameters. Parameter changes are reserved for offline P3 sweeps. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10195_tv-st-macd-ema]] - related single-Supertrend plus EMA200/MACD variant from the same source family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

