# QM5_10895_brown-bb-break - Strategy Spec

**EA ID:** QM5_10895
**Slug:** brown-bb-break
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades an intraday Bollinger breakout on the close of an M5 bar. A long entry requires the closed bar to break above the upper Bollinger Band while also closing above EMA(10), the Bollinger middle line, and EMA(50), with PSAR below price, MACD histogram above zero, RSI(14) above 50, and Slow Stochastic %K above %D. A short entry mirrors the same confirmations below the lower band. Exits use broker TP/SL from the card plus a strategy time exit after 24 bars if neither level is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >= 2 | Bollinger Band lookback period. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger Band standard deviation multiplier. |
| strategy_ema_fast_period | 10 | >= 1 | Fast EMA confirmation period. |
| strategy_ema_slow_period | 50 | >= 1 | Slow EMA confirmation period. |
| strategy_psar_step | 0.02 | > 0 | Parabolic SAR step. |
| strategy_psar_maximum | 0.20 | > 0 | Parabolic SAR maximum acceleration. |
| strategy_macd_fast | 12 | >= 1 | MACD fast EMA period. |
| strategy_macd_slow | 26 | > fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | >= 1 | MACD signal period. |
| strategy_rsi_period | 14 | >= 1 | RSI confirmation period. |
| strategy_rsi_midline | 50.0 | 0-100 | RSI long/short midpoint threshold. |
| strategy_stoch_k | 5 | >= 1 | Slow Stochastic K period. |
| strategy_stoch_d | 3 | >= 1 | Slow Stochastic D period. |
| strategy_stoch_slowing | 3 | >= 1 | Slow Stochastic slowing period. |
| strategy_atr_period | 14 | >= 1 | ATR period for normalized SL/TP. |
| strategy_sl_atr_mult | 0.8 | > 0 | ATR multiplier for stop distance. |
| strategy_sl_min_pips | 15 | >= 1 | Minimum stop distance in pips. |
| strategy_tp_atr_mult | 1.2 | > 0 | ATR multiplier for target distance. |
| strategy_tp_min_pips | 20 | >= 1 | Minimum target distance in pips. |
| strategy_max_hold_bars | 24 | >= 1 | Time exit after this many bars. |
| strategy_session_start_hour | 13 | 0-23 | Broker-hour active-session start. |
| strategy_session_end_hour | 17 | 0-23 | Broker-hour active-session end. |
| strategy_max_spread_stop_fraction | 0.20 | 0-1 | Blocks entries when spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 names EURUSD as a direct DWX forex target for this intraday breakout.
- GBPUSD.DWX - Card R3 names GBPUSD as a direct DWX forex target for this intraday breakout.
- USDCAD.DWX - Card R3 names USDCAD as a direct DWX forex target for this intraday breakout.
- USDJPY.DWX - Card R3 names USDJPY as a direct DWX forex target for this intraday breakout.

**Explicitly NOT for:**
- Non-DWX symbols - Build, backtest, and registry discipline require `.DWX` research symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | up to 24 M5 bars, about 2 hours |
| Expected drawdown profile | Intraday fixed-risk breakout drawdown, filtered by six confirmations and spread cap. |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** Jim Brown, FOREX TRADING the Basics Explained, local PDF file:///G:/My%20Drive/QuantMechanica/Ebook/PDF%20resources/FOREX%20TRADING%20the%20Basics%20Explai%20-%20Jim%20Brown.pdf, pp. 15, 20-24
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10895_brown-bb-break.md`

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
| v1 | 2026-06-14 | Initial build from card | 9b3a8547-8bb4-4d1c-9edd-04d647f2f9b4 |
