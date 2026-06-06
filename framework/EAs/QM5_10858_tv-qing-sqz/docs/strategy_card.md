---
ea_id: QM5_10858
slug: tv-qing-sqz
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "Z8830, Qing (EMA + MACD + Squeeze), TradingView open-source strategy, Apr 16, https://www.tradingview.com/script/PxAUrVvp-Qing-EMA-MACD-Squeeze/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/squeeze-breakout]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/volume-confirmation]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/macd]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 55
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL/author cited; R2 PASS mechanical EMA squeeze/MACD/volume entry plus ATR/time/indicator exits with ~55 trades/year/symbol; R3 PASS DWX OHLC/indicators/tick volume testable; R4 PASS fixed non-ML one-position rules."
---

# TradingView Qing EMA MACD Squeeze Breakout

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Qing (EMA + MACD + Squeeze)`, author handle `Z8830`, open-source strategy, accessed 2026-05-22, page shows Apr 16, https://www.tradingview.com/script/PxAUrVvp-Qing-EMA-MACD-Squeeze/

## Mechanik

### Entry
Use H1/H4 baseline:

- Compute EMA(6), EMA(12), EMA(20), EMA(50), EMA(100), and EMA(200).
- Detect squeeze when EMA(6), EMA(12), and EMA(20) are within a configurable percentage spread.
- Long setup: price closes above EMA(6), EMA(12), and EMA(20) after a squeeze.
- Require close > EMA(200).
- Require MACD bullish crossover or MACD line > signal line.
- Require volume spike above volume SMA * multiplier.
- Optional HTF filter: HTF close > HTF EMA(200).
- P2 baseline is long-only because the source description favors long setups.

### Exit
- ATR-based take-profit and stop-loss are set at entry.
- Close if price closes below EMA(20).
- Close if MACD crosses bearish.
- Time exit after 24 bars if no stop/target is hit.

### Stop Loss
- Initial stop = entry - ATR(14) * 1.5.
- Target = entry + ATR(14) * 3.0.
- V5 spread guard: skip if spread > 15% of stop distance.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Volume uses DWX tick volume; document weak tick-volume behavior during P2.
- Disable automatic equity-percent sizing; V5 fixed-risk sizing controls the trade.
- Squeeze and HTF parameters must remain fixed per run.

## Concepts (was ist das fur eine Strategie)
- [[concepts/squeeze-breakout]] - enters after short EMAs converge and price expands upward.
- [[concepts/trend-following]] - requires price above EMA200 and short EMA stack.
- [[concepts/volume-confirmation]] - requires a volume spike for breakout quality.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Z8830` are cited. |
| R2 Mechanical | PASS | Source gives EMA stack, squeeze detection, MACD confirmation, volume spike, HTF filter, and ATR SL/TP. |
| R3 Data Available | PASS | EMA, MACD, ATR, tick volume, HTF bars, and OHLC are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator and ATR rules, no ML, no grid, no martingale, one-position compatible. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy prioritizes systematic trend confirmation over speculative entries.
- Source says Qing Squeeze detects tight EMA(6/12/20) consolidation that often precedes explosive moves.
- Source says MACD crossovers and volume spikes filter low-conviction breakouts.
- Source says risk management uses dynamic ATR-based stop-loss and take-profit levels.

## Parameters To Test
- Timeframe: H1, H4.
- Squeeze tightness: 0.25%, 0.50%, 0.75%.
- Volume multiplier: 1.2, 1.5, 2.0.
- HTF filter: off, H4, D1.
- ATR stop: 1.0, 1.5, 2.0.
- ATR target: 2.0, 3.0, 4.0.

## Initial Risk Profile
Moderate-cadence squeeze breakout. Main risks are delayed entries after the expansion candle and unreliable tick-volume spike confirmation on some CFDs.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView mechanical strategy source.

## Verwandte Strategien
- QM5_10839 tv-momo-slope
- QM5_10846 tv-growth-bo

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
