# QM5_38004_codetrading-triple-ema-momentum-scalper — Strategy Spec

**EA ID:** QM5_38004
**Slug:** codetrading-triple-ema-momentum-scalper
**Source:** codetrading-triple-ema-momentum-scalper-official-source (see `strategy-seeds/sources/codetrading-triple-ema-momentum-scalper/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy is an ultra-fast intraday momentum scalper on the M5 timeframe utilizing an 8, 21, and 55 Exponential Moving Average (EMA) ribbon alignment. All evaluations occur strictly on closed bars (Shift = 1).

A Long entry is triggered when the bullish ribbon is established (`EMA(8) > EMA(21) > EMA(55)`), price pulls back into the pocket (`Low[1] <= EMA(8)[1]` and `Close[1] > EMA(21)[1]`), and the bar closes bullish (`Close[1] > Open[1]`). A Short entry is triggered when the bearish ribbon is established (`EMA(8) < EMA(21) < EMA(55)`), price pulls back into the pocket (`High[1] >= EMA(8)[1]` and `Close[1] < EMA(21)[1]`), and the bar closes bearish (`Close[1] < Open[1]`).

Stop Loss is anchored beyond the 55 EMA baseline with a 2.0-pip buffer. Take Profit is set at a 1:2.0 Risk-to-Reward ratio. Open positions are trailed along the 21 EMA line once floating profit reaches +1.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | `M1-M15` | Base execution and indicator timeframe |
| `strategy_fast_ema_period` | `8` | `5-12` | Fast trigger EMA period |
| `strategy_med_ema_period` | `21` | `15-30` | Medium trend baseline EMA period |
| `strategy_slow_ema_period` | `55` | `40-80` | Slow regime baseline EMA period |
| `strategy_atr_period` | `14` | `10-20` | ATR period for spread filtering and fallbacks |
| `strategy_sl_buffer_pips` | `2.0` | `1.0-5.0` | Pip buffer beyond 55 EMA for Stop Loss |
| `strategy_tp_rr` | `2.0` | `1.0-3.0` | Risk-to-Reward multiplier for Take Profit |
| `strategy_trail_enabled` | `true` | `true/false` | Trail stop loss along 21 EMA once in profit |
| `strategy_trail_trigger_r` | `1.0` | `0.5-2.0` | Profit threshold in R-multiples to activate trailing |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Primary high-momentum US tech index with clean trending moves and well-behaved EMA pullbacks
- `WS30.DWX` — Liquid US large-cap index with reliable M5 micro-pullback continuation
- `GDAXI.DWX` — Liquid European benchmark index with strong intraday momentum bursts

**Explicitly NOT for:**
- Low-volatility or choppy range-bound instruments where EMA ribbons whipsaw

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | 15 minutes to 3 hours |
| Expected drawdown profile | Low, < 3% Max Drawdown |
| Regime preference | Trending / Momentum Contraction-Expansion |
| Win rate target (qualitative) | High (65-75%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-triple-ema-momentum-scalper-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2021). Simple EMA Scalping Trading Strategy Backtest In Python. YouTube.`
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38004_codetrading-triple-ema-momentum-scalper.md`

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
| v1 | 2026-08-18 | Initial build from card | Task 952a07fb-63c7-4fc3-9582-83096a13c9e0 |
