---
ea_id: QM5_10180
slug: tv-fut-ema-rsi-pull
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/pullback-continuation]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 140
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL cited; R2 mechanical EMA/RSI pullback entries with ATR bracket/time exits and ~140 trades/year/symbol; R3 testable on DWX indices/gold with SP500 caveat; R4 no ML/grid/martingale, one position per magic."
---

# TradingView Futures EMA RSI Pullback

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `All-Day Futures Trend Pullback (EMA + RSI) [v5]`, author handle `bradenstrock`, published 2026-03-05, https://www.tradingview.com/script/9tPTFXRh-All-Day-Futures-Trend-Pullback-EMA-RSI-v5/

## Mechanik

### Entry
Use M15 or M30 bars, long and short.

- Compute EMA(100) on close.
- Compute RSI(14).
- Long trend state: close > EMA(100).
- Short trend state: close < EMA(100).
- Long entry: long trend state and RSI(14) <= 35.
- Short entry: short trend state and RSI(14) >= 65.
- Use one open position per magic; ignore additional pullback signals while in position.

### Exit
- Baseline uses ATR bracket exits.
- Long stop: entry - 1.5 ATR(14); long target: entry + 2.0 ATR(14).
- Short stop: entry + 1.5 ATR(14); short target: entry - 2.0 ATR(14).
- Optional source trailing stop is disabled for P2 baseline to keep the first test lower-dimensional.
- Close at end of configured session if a session filter is enabled; otherwise close after 32 bars.

### Stop Loss
- ATR-based stop, fixed at entry.
- Do not widen after entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Primary DWX port: NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX.
- Optional SP500.DWX backtest analog is allowed.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
- Skip high-impact US macro release windows for index/gold tests.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - EMA defines directional regime.
- [[concepts/pullback-continuation]] - RSI pullback is bought or sold in the trend direction.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `bradenstrock` are cited. |
| R2 Mechanical | PASS | Source specifies EMA trend direction, RSI pullback entries, bracket exits, session option, and fixed contract sizing. |
| R3 Data Available | PASS | Futures OHLC/indicator logic ports to DWX index CFDs and gold; SP500.DWX caveat included. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, pyramiding, or live performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10110_tv-sma20-200-pullback]] - related trend pullback continuation with SMA regime logic.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
