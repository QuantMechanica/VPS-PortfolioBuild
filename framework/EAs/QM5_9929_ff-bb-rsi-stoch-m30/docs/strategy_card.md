---
ea_id: QM5_9929
slug: ff-bb-rsi-stoch-m30
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "pusztafie, BB RSI Stochastic, ForexFactory, 2025, https://www.forexfactory.com/thread/post/15327024"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/bollinger-pullback]]"
  - "[[concepts/oscillator-confirmation]]"
  - "[[concepts/higher-timeframe-trend-filter]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/rsi]]"
  - "[[indicators/stochastic]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M30
expected_trade_frequency: "Medium; Bollinger-band pullbacks with H4 trend and dual oscillator confirmation should produce roughly 35-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS linked ForexFactory source/handle; R2 PASS deterministic BB/RSI/Stoch/H4 EMA entries and exits with ~55 trades/year/symbol; R3 PASS DWX FX/metals OHLC indicators; R4 PASS fixed rules one-position no ML/grid/martingale."
---

# ForexFactory BB RSI Stochastic Pullback M30

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: pusztafie, "BB, RSI, Stochastic", ForexFactory, 2025, URL https://www.forexfactory.com/thread/post/15327024.
- Thread: "BB, RSI, Stochastic".
- Author / handle: `pusztafie`.
- URL: https://www.forexfactory.com/thread/post/15327024
- Source location: post #66 gives System V2.0: H4 EMA(50) trend filter, Bollinger(50,2) pullback, RSI(7) and Stochastic(14,3,3) overbought/oversold confirmation, candlestick trigger, ATR stop, TP1 at middle band, TP2 at opposite band.

## Mechanik

### Entry
- Execute on M30 closed bars; H4 trend filter uses completed H4 bar.
- Long setup:
  - M30 close is above EMA(50,H4).
  - Previous M30 candle closed below lower Bollinger Band(50,2).
  - On that same previous candle, RSI(7) < 30 and Stochastic(14,3,3) %K < 20.
  - Current M30 candle closes back above the lower Bollinger Band.
  - Current candle is bullish engulfing or bullish pin-style: lower wick >= 1.5 body and close in upper 40% of range.
- Enter long at next M30 open. Short setup mirrors below H4 EMA(50), prior close above upper band, RSI > 70, Stochastic > 80, bearish trigger back inside band.

### Exit
- TP1: Bollinger middle band SMA(50); close 50% of position.
- After TP1, move remaining SL to entry.
- TP2: opposite Bollinger Band.
- Exit remaining position if close crosses back through entry-side band against the trade.
- Time stop: 20 M30 bars.

### Stop Loss
- Initial SL for long: entry candle low - `1.5 * ATR(14,M30)`.
- Initial SL for short: entry candle high + `1.5 * ATR(14,M30)`.
- Skip if initial stop exceeds 2.8 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Require ATR(14,M30) above a configurable minimum; default is above its 100-bar 20th percentile.
- One active position per magic-symbol.

## Concepts
- [[concepts/bollinger-pullback]] - primary
- [[concepts/oscillator-confirmation]] - secondary
- [[concepts/higher-timeframe-trend-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory post URL plus named handle `pusztafie`. |
| R2 Mechanical | PASS | Source gives exact BB/RSI/Stochastic/EMA/ATR rules; candlestick trigger is codified into fixed engulfing/pin tests. |
| R3 DWX-testbar | PASS | Uses standard OHLC indicators available on DWX FX/metals. |
| R4 No ML | PASS | Fixed parameters and one-position-per-magic; no ML, adaptive tuning, grid, martingale, or averaging. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9197_mql5-bb-stoch-mtf]] - also BB/Stochastic; this card adds RSI(7), H4 EMA trend, and candlestick trigger from the FF source.
- [[strategies/QM5_9907_bandy-bbands-midband-reversion-mr-index]] - Bollinger mean reversion on indices; this card is trend-aligned FX/metals pullback.

## Lessons Learned
- TBD during pipeline run.
