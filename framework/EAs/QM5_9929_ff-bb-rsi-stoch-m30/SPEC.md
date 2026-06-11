# QM5_9929_ff-bb-rsi-stoch-m30 - Strategy Spec

**EA ID:** QM5_9929
**Slug:** ff-bb-rsi-stoch-m30
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M30 Bollinger Band pullbacks only in the direction of the completed H4 EMA(50) trend filter. A long setup requires the prior M30 close below the lower Bollinger Band(50,2), RSI(7) below 30, Stochastic(14,3,3) %K below 20, and the latest closed M30 candle closing back above the lower band with either a bullish engulfing candle or a bullish pin-style candle. Shorts mirror the rule at the upper band with RSI above 70, Stochastic above 80, and a bearish trigger candle. The initial stop is placed beyond the trigger candle by 1.5 ATR(14), TP1 partially closes at the Bollinger middle band, TP2 is the opposite band, and any remaining position exits after 20 M30 bars or on a close back through the entry-side band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M30` | M30 expected | Base timeframe for Bollinger, RSI, Stochastic, ATR, and candle trigger. |
| `strategy_trend_tf` | `PERIOD_H4` | H4 expected | Higher timeframe for the EMA trend filter. |
| `strategy_bb_period` | 50 | >= 1 | Bollinger Band moving average period. |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger Band standard deviation multiplier. |
| `strategy_rsi_period` | 7 | >= 1 | RSI period used on the prior setup candle. |
| `strategy_stoch_k` | 14 | >= 1 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | >= 1 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | >= 1 | Stochastic slowing value. |
| `strategy_h4_ema_period` | 50 | >= 1 | H4 EMA period for trend direction. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for stop distance and volatility filter. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long setup RSI threshold. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Short setup RSI threshold. |
| `strategy_stoch_oversold` | 20.0 | 0-100 | Long setup Stochastic %K threshold. |
| `strategy_stoch_overbought` | 80.0 | 0-100 | Short setup Stochastic %K threshold. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | ATR multiple added beyond trigger candle high/low for initial SL. |
| `strategy_max_stop_atr_mult` | 2.8 | > 0 | Maximum allowed initial stop distance in ATR units. |
| `strategy_atr_percentile_lookback` | 100 | >= 1 | Bars used to estimate the ATR percentile filter. |
| `strategy_min_atr_percentile` | 20.0 | 0-100 | Minimum ATR percentile required before entry. |
| `strategy_pin_wick_body_mult` | 1.5 | > 0 | Minimum wick/body ratio for pin-style trigger candles. |
| `strategy_pin_close_zone_pct` | 40.0 | 0-100 | Close-location zone for pin-style trigger candles. |
| `strategy_tp1_close_percent` | 50.0 | 0-100 | Position percent to close at Bollinger middle band. |
| `strategy_time_stop_bars` | 20 | >= 1 | Maximum holding period in M30 bars. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX M30/H4 OHLC data.
- `GBPUSD.DWX` - card-listed liquid FX major with DWX M30/H4 OHLC data.
- `USDJPY.DWX` - card-listed liquid FX major with DWX M30/H4 OHLC data.
- `XAUUSD.DWX` - card-listed gold/metals symbol with DWX M30/H4 OHLC data.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research/backtest registry requires the `.DWX` canonical symbol names.
- Equity indices and energy symbols - they are outside the card's R3 FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | H4 EMA(50) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Intraday, capped at 20 M30 bars (about 10 hours) |
| Expected drawdown profile | Moderate fixed-risk pullback strategy with ATR-capped initial stops |
| Regime preference | Trend-aligned Bollinger pullback / mean reversion |
| Win rate target (qualitative) | Medium |
| Expected trade frequency | Medium; roughly 35-80 trades/year/symbol |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/post/15327024
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9929_ff-bb-rsi-stoch-m30.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 69dea56f-281b-44a1-b59f-028bf82988a9 |
