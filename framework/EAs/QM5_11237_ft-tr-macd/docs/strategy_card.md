---
ea_id: QM5_11237
slug: ft-tr-macd
type: strategy
source_id: 1580128f-e465-5454-bb97-a7572a6cfd6d
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/freqtrade-strategies]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/adx]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 28
last_updated: 2026-05-23
card_body_incomplete: false
card_body_missing: ""
g0_approval_reasoning: "R1 single GitHub source_id/URL; R2 H1 MACD/EMA/RSI/ADX/volume entry plus deterministic exits supports plausible 28 trades/year/symbol; R3 DWX OHLC/tick-volume indicators available; R4 no ML, deterministic one-position logic."
---

# Freqtrade TrendRider MACD Reversal

## Quelle
- Source: [[sources/freqtrade-strategies]]
- Page / Timestamp: 2026 URL file `user_data/strategies/TrendRiderStrategy.py`, entry tag `macd_reversal`, repository `freqtrade/freqtrade-strategies`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/TrendRiderStrategy.py

Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

## Mechanik

### Entry
Use H1 as source timeframe. Long when all are true:
- MACD histogram crosses above zero
- close > EMA(50)
- close > EMA(200)
- RSI(16) > 40 and RSI(16) < 60
- ADX(14) > 15
- volume ratio > 0.8 using current volume / EMA(20) volume
- volume > 0
- BTC/fear-greed source filters are disabled or neutralized for DWX port
- one active position maximum

### Exit
Use the source TrendRider long exits:
- RSI(16) > 78
- or EMA(9) crosses below EMA(16) with MACD histogram < 0 and RSI(16) > 50
- or close crosses below EMA(200) * 0.99
- or close < EMA(200) * 0.995 and RSI(16) > 72 and MACD histogram is falling

Custom time/loss exits:
- after 2h, exit if profit < -1.5%
- after 4h, exit if profit < 0%
- after 8h, exit if profit < 0.5%
- after 16h, exit if profit < 1.0%
- after 24h, exit regardless

### Stop Loss
Source fixed stoploss is `-0.06`; trailing stop activates after +5% with 3% trail. V5 emergency stop: min(source stop, 3.0 * ATR(14)).

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
This card isolates the source `macd_reversal` entry tag. It keeps the source long-only behavior and does not mirror to shorts at G0.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum]] - MACD histogram crosses from negative to positive while RSI remains mid-range.
- [[concepts/trend-filter]] - EMA50/EMA200 require the reversal to occur above the primary trend averages.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact GitHub URL, repository, commit, and entry tag are cited. |
| R2 Mechanical | PASS | Entry, source exits, trailing stop, fixed stop, and time exits are deterministic. |
| R3 Data Available | PASS | OHLC, MACD, EMA, RSI, ADX, ATR, and tick volume are available on DWX instruments. |
| R4 ML Forbidden | PASS | No ML; hyperopt values are frozen constants; one-position compatible; no grid/martingale. |

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING, drafted from Freqtrade community strategy source.

## Verwandte Strategien
- [[strategies/QM5_11235_ft-tr-emax]] - Same source, EMA crossover variant.
- [[strategies/QM5_11236_ft-tr-bb]] - Same source, Bollinger bounce variant.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
