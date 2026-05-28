---
ea_id: QM5_10259
slug: tv-stoch-rsi
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/momentum-confluence]]"
  - "[[concepts/swing-risk]]"
indicators:
  - "[[indicators/stochastic]]"
  - "[[indicators/rsi]]"
  - "[[indicators/macd]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: EURUSD.DWX
expected_trades_per_year_per_symbol: 20
last_updated: 2026-05-19
g0_approval_reasoning: "R1 public TradingView URL cited; R2 stochastic/RSI/MACD confluence entries with swing stop and 1.5R exit mechanical with ~20 trades/year; R3 indicators testable on DWX CFDs; R4 fixed rules no ML/grid/martingale."
---

# QM5_10259 TradingView Stoch RSI MACD Confluence

## Quelle
- Source: TradingView Pine script "Data Trader Stoch | RSI | MACD Strategy Indicator"
- URL: https://www.tradingview.com/script/Sxz75MZJ-Data-Trader-Stoch-RSI-MACD-Strategy-Indicator/
- Author: CryptoniteClark (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView script page, open-source indicator, updated 2021-11-01.

## Mechanik

### Entry
- Baseline timeframe: H1 or H4 due to source warning that the setup generates sparse signals.
- Compute Stochastic %K/%D, RSI, and MACD.
- Long entry when:
  - Stochastic %K and %D are both oversold; P1 default threshold 20.
  - RSI is above its midline; P1 default RSI > 50.
  - MACD line is above the signal line.
- Short entry when:
  - Stochastic %K and %D are both overbought; P1 default threshold 80.
  - RSI is below its midline; P1 default RSI < 50.
  - MACD line is below the signal line.

### Exit
- Take profit at 1.5R from entry, matching the source.
- Optional P3 variant exits on opposite confluence signal if it arrives before TP/SL.

### Stop Loss
- Long stop below the last swing low.
- Short stop above the last swing high.
- P1 default swing definition: confirmed fractal pivot with left/right lookback 3 bars.

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.
- One open position per magic number.

### Zusaetzliche Filter
- Reject trades where swing-stop distance is below 0.5 * ATR(14) or above 3.0 * ATR(14), to avoid tiny/noisy stops and excessive risk width.
- Standard V5 spread, news, kill-switch, Friday-close, and max-DD filters.
- Best DWX ports: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX.

## Concepts
- [[concepts/momentum-confluence]] - primary; stochastic exhaustion, RSI bias, and MACD direction must agree.
- [[concepts/swing-risk]] - stop is anchored to the most recent confirmed swing.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle CryptoniteClark are cited. |
| R2 Mechanical | PASS | Source gives long/short confluence rules, swing-based stops, and 1.5R profit target. |
| R3 Data Available | PASS | Stochastic, RSI, MACD, swing pivots, ATR, and OHLC bars are available on DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator confluence only; no ML, grid, martingale, DCA, or adaptive online parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10257_tv-sma-rsi-macd]] - faster intraday RSI/MACD scalping sibling.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Keep cadence expectations low. The source itself notes sparse signals, so H1/H4 baseline is more appropriate than forcing intraday overtrading.
