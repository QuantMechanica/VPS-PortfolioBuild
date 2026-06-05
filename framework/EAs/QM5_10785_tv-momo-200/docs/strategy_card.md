---
ea_id: QM5_10785
slug: tv-momo-200
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "martinearthheaven, Momentum Breakout | 200SMA + MACD + StochRSI, TradingView open-source strategy, https://www.tradingview.com/script/gYkIvFGi-Momentum-Breakout-200SMA-MACD-StochRSI/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/momentum-breakout]]"
  - "[[concepts/trend-filter]]"
  - "[[concepts/swing-target]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/macd]]"
  - "[[indicators/stochastic-rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL+handle; R2 PASS mechanical SMA/MACD/StochRSI entries plus deterministic swing exits with ~60 trades/year/symbol; R3 PASS DWX OHLC indicators testable; R4 PASS fixed non-ML one-position rules."
---

# TradingView 200SMA MACD StochRSI Momentum Breakout

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Momentum Breakout | 200SMA + MACD + StochRSI`, author handle `martinearthheaven`, open-source strategy, page shows May 1, accessed 2026-05-22, https://www.tradingview.com/script/gYkIvFGi-Momentum-Breakout-200SMA-MACD-StochRSI/

## Mechanik

### Entry
Use M15/H1 baseline.

- Compute SMA(200).
- Compute MACD using standard 12/26/9 baseline unless source code exposes different defaults.
- Compute Stochastic RSI.
- Long setup:
  - Price crosses above SMA(200).
  - MACD line is greater than 0.
  - Stochastic RSI %K is greater than 80.
  - No existing position.
- Short setup:
  - Price crosses below SMA(200).
  - MACD line is less than 0.
  - Stochastic RSI %K is less than 20.
  - No existing position.

### Exit
- Source target: recent resistance for longs and recent support for shorts.
- V5 deterministic target: most recent confirmed swing high/low in trade direction; fallback fixed R target if no valid swing exists.
- Close on opposite SMA(200) cross or max-bars-in-trade.

### Stop Loss
- Source stop: below recent support for longs and above recent resistance for shorts.
- V5 deterministic stop: most recent confirmed swing low/high with ATR buffer.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- ADX trend-strength filter may be tested as a P3 axis.
- ATR minimum movement filter may be tested to avoid tiny SMA crosses.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum-breakout]] - enters only when price crosses the long-term average with momentum confirmation.
- [[concepts/trend-filter]] - SMA(200) defines the regime boundary.
- [[concepts/swing-target]] - stop and target are anchored to recent structural levels.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `martinearthheaven` are cited. |
| R2 Mechanical | PASS | Source gives explicit long/short entries plus swing-based TP/SL concepts that can be made deterministic with confirmed pivots. |
| R3 Data Available | PASS | SMA, MACD, Stochastic RSI, OHLC swings, and ATR buffers are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator rules; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says long entry requires price crossing above SMA(200), MACD above zero, and Stochastic RSI %K above 80.
- Source says short entry requires price crossing below SMA(200), MACD below zero, and Stochastic RSI %K below 20.
- Source says TP is set at recent resistance and SL below recent support.

## Parameters To Test
- Timeframe: M15, M30, H1.
- SMA length: 100, 200.
- MACD: 12/26/9, 8/21/5.
- StochRSI long threshold: 70, 80.
- StochRSI short threshold: 30, 20.
- Swing lookback: 5, 10, 20 bars.
- Fallback R:R target: 1.5, 2.0.

## Initial Risk Profile
Generic momentum breakout. Main risk is late entry after SMA cross and correlated losses during whipsaw regimes.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10761 tv-vortex
- QM5_10762 tv-trend-brk
- QM5_10776 tv-rsi-macd-ema

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
