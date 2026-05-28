---
ea_id: QM5_10257
slug: tv-sma-rsi-macd
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/scalping]]"
  - "[[concepts/momentum-pullback]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/sma]]"
  - "[[indicators/rsi]]"
  - "[[indicators/macd]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: EURUSD.DWX
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL+author cited; R2 mechanical SMA/RSI/MACD scalper with ATR/2R exits and ~180 trades/year/symbol; R3 DWX FX/index CFDs testable; R4 fixed-rule non-ML one-position logic."
---

# QM5_10257 TradingView SMA RSI MACD Scalper

## Quelle
- Source: TradingView Pine script "Scalper SMA-RSI-MACD - Entry/Exit Signals v2"
- URL: https://www.tradingview.com/script/DWzDv6Do-Scalper-SMA-RSI-MACD-Entry-Exit-Signals-v2/
- Author: Oberon777 (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView script page, open-source indicator, published 2025-08-14.

## Mechanik

### Entry
- Baseline timeframe: M5; M1 is not used for P2 because spread sensitivity is too high.
- Compute EMA(200) and SMA ribbon using SMA(5), SMA(8), SMA(13).
- Compute RSI(4), MACD default 12/26/9, and ATR(14).
- Long entry when:
  - Trend filter is up: close > EMA(200) and SMA(5) > SMA(8) > SMA(13).
  - RSI(4) has produced an oversold pullback condition.
  - MACD bullish crossover or bullish momentum turn occurs within the last 3 bars.
- Short entry when:
  - Trend filter is down: close < EMA(200) and SMA(5) < SMA(8) < SMA(13).
  - RSI(4) has produced an overbought pullback condition.
  - MACD bearish crossover or bearish momentum turn occurs within the last 3 bars.

### Exit
- Source supports TP1, TP2, or opposite-signal exit.
- V5 baseline exits full position at TP2 = 2R or stop, whichever comes first.
- P3 variants test TP1 = 1R and opposite-signal exit.

### Stop Loss
- Source default: 1.5 * ATR from entry.
- P3 sweep: 1.2, 1.5, 2.0 ATR.

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.
- One open position per magic number.

### Zusaetzliche Filter
- Optional source session filter: baseline uses London/NY overlap for FX and regular liquid hours for indices.
- Standard V5 spread, news, kill-switch, Friday-close, and max-DD filters.
- Best DWX ports: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

## Concepts
- [[concepts/scalping]] - primary; intraday 1m-5m source usage.
- [[concepts/momentum-pullback]] - RSI pullback followed by MACD momentum turn.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle Oberon777 are cited. |
| R2 Mechanical | PASS | Source gives EMA/SMA trend filter, RSI pullback, MACD lookback, ATR SL, R-multiple TP, and opposite-signal exit. |
| R3 Data Available | PASS | OHLC, EMA, SMA, RSI, MACD, ATR, and sessions are available on DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules only; no ML, grid, martingale, DCA, or online parameter adaptation. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9168_tv-elaris-confluence-scalping]] - higher-confluence scalping sibling.
- [[strategies/QM5_10250_tv-bb-scalp]] - Bollinger scalping sibling.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Define RSI pullback baseline as RSI(4) crossing back above 30 for longs and back below 70 for shorts unless Pine source code exposes different thresholds.
