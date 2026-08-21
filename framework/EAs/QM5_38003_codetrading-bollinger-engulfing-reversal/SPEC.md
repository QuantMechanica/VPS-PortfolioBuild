# QM5_38003_codetrading-bollinger-engulfing-reversal — Strategy Spec

**EA ID:** QM5_38003
**Slug:** codetrading-bollinger-engulfing-reversal
**Source:** codetrading-bollinger-engulfing-reversal-official-source (see `strategy-seeds/sources/codetrading-bollinger-engulfing-reversal/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy is a systematic price action mean-reversion model on the H1 timeframe combining Bollinger Bands (20, 2.0), RSI(14) momentum filters, and Engulfing candlestick patterns. All evaluations occur strictly on closed bars (Shift = 1).

A Long entry is triggered when Bar 1 forms a Bullish Engulfing pattern over Bar 2 (Bar 2 is bearish, Bar 1 is bullish and engulfs Bar 2's body), the Low of Bar 1 penetrates or touches the Lower Bollinger Band, and RSI(14) is oversold (<= 35.0). A Short entry is triggered when Bar 1 forms a Bearish Engulfing pattern over Bar 2 (Bar 2 is bullish, Bar 1 is bearish and engulfs Bar 2's body), the High of Bar 1 penetrates or touches the Upper Bollinger Band, and RSI(14) is overbought (>= 65.0).

Stop Loss is placed beyond the extreme of the engulfing candle (Low - 2.0 pips for Long, High + 2.0 pips for Short). Take Profit is set at 2.0× Risk-to-Reward (1:2.0 R:R). Floating positions protect profits by moving Stop Loss to Break-Even when price reaches the 20 SMA Middle Bollinger Band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `M30-H4` | Base execution and indicator timeframe |
| `strategy_bb_period` | `20` | `14-30` | Bollinger Bands period |
| `strategy_bb_dev` | `2.00` | `1.5-2.5` | Bollinger Bands standard deviation multiplier |
| `strategy_rsi_period` | `14` | `7-21` | RSI oscillator period |
| `strategy_rsi_long_max` | `35.0` | `20.0-40.0` | RSI threshold for Long entries |
| `strategy_rsi_short_min` | `65.0` | `60.0-80.0` | RSI threshold for Short entries |
| `strategy_atr_period` | `14` | `10-20` | ATR period for spread filtering and fallbacks |
| `strategy_sl_buffer_pips` | `2.0` | `1.0-5.0` | Pip buffer beyond engulfing candle extreme for SL |
| `strategy_tp_rr` | `2.0` | `1.0-3.0` | Risk-to-Reward multiplier for Take Profit |
| `strategy_mid_exit_enabled` | `true` | `true/false` | Move SL to Break-Even when price touches middle band |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX major with high mean-reverting quality at H1 Bollinger Band extremes
- `GBPJPY.DWX` — Volatile FX cross offering strong engulfing momentum follow-through
- `AUDUSD.DWX` — Major commodity currency pair with well-defined cyclical range extremes

**Explicitly NOT for:**
- Illiquid exotic pairs or high-spread instruments where spread widening degrades risk-reward efficiency

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 4 to 24 hours |
| Expected drawdown profile | Low, < 4% Max Drawdown with disciplined 1:2 R:R |
| Regime preference | Ranging / Overextended Extremes Mean Reversion |
| Win rate target (qualitative) | High (65-75%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-bollinger-engulfing-reversal-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2022). How To Trade Candles Patterns | Strategy Backtest In Python. YouTube.`
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38003_codetrading-bollinger-engulfing-reversal.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task 5fa16349-5252-448a-8f5d-8a7d77306f9b |
