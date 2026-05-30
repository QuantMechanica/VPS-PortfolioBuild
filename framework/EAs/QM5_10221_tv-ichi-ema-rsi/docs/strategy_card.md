---
ea_id: QM5_10221
slug: tv-ichi-ema-rsi
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/cloud-breakout]]"
indicators:
  - "[[indicators/ichimoku-cloud]]"
  - "[[indicators/exponential-moving-average]]"
  - "[[indicators/stochastic-rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 55
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author; R2 mechanical Ichimoku/EMA/StochRSI entry and cloud exit, ~55 trades/year/symbol; R3 crypto concept portable to DWX FX/gold/index CFDs; R4 fixed-rule non-ML one-position strategy."
---

# TradingView Ichimoku EMA RSI

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Ichimoku EMA RSI - Crypto only long Strategy`, author handle `TradingStrategyCheck`, published 2021-06-02, updated 2021-07-05, https://www.tradingview.com/script/IYQMk5fS/

## Target Symbols
EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX.

## Mechanik

### Entry
Baseline uses H4. Long when Senkou Span A, the green Ichimoku lead line, is above Senkou Span B and a bullish candle closes above Senkou Span A. Optional source filters become baseline-on for first test: EMA1 > EMA2 and Stochastic RSI K > D.

### Exit
Close the long when a bearish candle closes below Senkou Span A. The source later added short capability; baseline is long-only to preserve the originally described rule.

### Stop Loss
Source does not specify a hard stop. Use V5 protective stop at the lower of recent swing low or 2.5 * ATR below entry for P2; let P3 sweep ATR multiplier.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
No crypto-specific dependency is required. Port ETH/USDT H4 concept to liquid DWX trend instruments, especially XAUUSD, GBPJPY, NDX, and GER40.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - follows sustained cloud-aligned moves.
- [[concepts/cloud-breakout]] - requires candle close above the active Ichimoku lead line.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `TradingStrategyCheck` are cited. |
| R2 Mechanical | PASS | Source gives Ichimoku entry, Ichimoku exit, optional EMA filter, and optional Stochastic RSI filter. |
| R3 Data Available | PASS | Ichimoku, EMA, Stochastic RSI, ATR, and OHLC data are available on DWX FX, gold, and index CFDs after crypto-to-CFD port. |
| R4 ML Forbidden | PASS | Fixed indicator rules; no ML, grid, martingale, or adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10130_tv-kumo-trade]] - Ichimoku cloud family if present in approved set.
- [[strategies/QM5_10195_tv-st-macd-ema]] - trend-filter confluence family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
