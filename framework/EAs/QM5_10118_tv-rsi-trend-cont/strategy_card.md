---
ea_id: QM5_10118
slug: tv-rsi-trend-cont
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "Skyrexio, RSI Trend Following Strategy, TradingView, 2024-09-01, https://in.tradingview.com/script/mwyj1IWU-RSI-Trend-Following-Strategy/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum-confirmation]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/macd]]"
  - "[[indicators/stochastic]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]
period: H2
expected_trade_frequency: "Source reports 111 BTC trades over ~19 months on 2H; ported filtered long-only estimate 45-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS TradingView URL/author; R2 PASS mechanical RSI/MACD/Stoch/EMA/ATR entry-exit-stop with ~55 trades/year/symbol; R3 PASS ports to DWX FX/gold/index CFDs; R4 PASS fixed rules no ML/grid/martingale."
---

# TradingView RSI Trend Continuation

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: Skyrexio, "RSI Trend Following Strategy", TradingView, 2024-09-01, URL https://in.tradingview.com/script/mwyj1IWU-RSI-Trend-Following-Strategy/.
- Author / handle: `Skyrexio`.
- Source location: public methodology defines long-only RSI > 50, MACD line > signal, Stochastic lines <= 80, candle low above EMA200, ATR stop, and EMA trailing exit after ATR profit activation.

## Mechanik

### Entry
- Baseline parameters:
  - RSI length 14.
  - MACD 12/26/9 using EMA.
  - Stochastic %K/%D length 14 with standard smoothing.
  - EMA(200).
  - ATR length 14.
- Long entry when all conditions are true:
  - RSI(14) > 50.
  - MACD line > MACD signal line.
  - Stochastic %K <= 80 and %D <= 80.
  - Candle low > EMA(200).
- No short entries.

### Exit
- Initial stop is active immediately.
- When close >= entry + 2.25 * ATR(14), activate trailing mode.
- After trailing mode is active, close long when close < EMA(20).

### Stop Loss
- Long stop: entry price - 1.75 * ATR(14).
- Recalculate ATR stop only in the source-defined volatility-stop sense; do not alter ATR multiplier from live performance.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Source uses 30% capital; do not use percent-of-equity sizing in P2.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Trade H2 if platform supports it; otherwise H1 with parameters unchanged.
- Skip if spread > 10% of ATR stop distance.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/momentum-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL plus author handle `Skyrexio`. |
| R2 Mechanical | PASS | Entry filters, ATR stop, profit activation, and EMA trailing close are explicit. |
| R3 DWX-testbar | PASS | RSI/MACD/Stochastic/EMA/ATR rules port to DWX FX, gold, and index CFDs. |
| R4 No ML | PASS | Fixed indicator formulas and fixed ATR multipliers; no ML, grid, martingale, or online parameter adaptation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10117_tv-ma-psar-atr-trend]] - another long/short trend-filter card; this one is long-only and momentum-confirmed.

## Lessons Learned
- TBD during pipeline run.
