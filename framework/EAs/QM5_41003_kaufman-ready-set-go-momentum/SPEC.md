# QM5_41003_kaufman-ready-set-go-momentum — Strategy Spec

**EA ID:** QM5_41003
**Slug:** kaufman-ready-set-go-momentum
**Source:** kaufman-ready-set-go-momentum-official-source (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41003_kaufman-ready-set-go-momentum.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy implements Perry Kaufman's 3-stage momentum filter model on the H1 timeframe. All indicator evaluations and entry triggers are executed strictly at the close of bar [1] (Shift = 1).

Stage 1 ('Ready') tests for volatility compression: fast ATR(10)[1] must be less than baseline slow ATR(30)[1].

Stage 2 ('Set') evaluates the directional trend filter: Close[1] > EMA(50)[1] for Long setups, or Close[1] < EMA(50)[1] for Short setups.

Stage 3 ('Go') evaluates momentum acceleration breakout: Close[1] - Close[5] > 1.5× ATR(10)[1] for Long entry, or Close[5] - Close[1] > 1.5× ATR(10)[1] for Short entry.

Stop Loss is placed at 1.5× ATR(10, H1)[1] from the entry price. Take Profit is placed at 2.0× Stop Loss distance (1:2.0 Risk-to-Reward ratio).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `H1` | Base execution and indicator timeframe |
| `strategy_fast_atr_period` | `10` | `5-15` | Fast ATR compression period |
| `strategy_slow_atr_period` | `30` | `20-50` | Slow baseline ATR period |
| `strategy_trend_ema_period` | `50` | `30-80` | Directional trend EMA period |
| `strategy_momentum_bars` | `5` | `3-10` | Lookback bar count for momentum acceleration |
| `strategy_go_atr_mult` | `1.5` | `1.0-2.5` | ATR multiplier threshold for Go momentum |
| `strategy_sl_atr_mult` | `1.5` | `1.0-2.5` | Multiplier on ATR for stop loss placement |
| `strategy_tp_rr_mult` | `2.0` | `1.5-3.0` | Take profit multiple relative to stop distance |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — Primary US large cap equity index CFD with robust intraday momentum swings
- `NDX.DWX` — High-beta tech index CFD exhibiting high-acceleration momentum surges
- `GDAXI.DWX` — European benchmark equity index CFD with clean H1 momentum waves

**Explicitly NOT for:**
- Illiquid, wide-spread crosses or range-bound assets without momentum follow-through

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
| Typical hold time | 4 hours to 3 days |
| Expected drawdown profile | Low to Moderate, < 15% Max Drawdown |
| Regime preference | High Volatility / Strong Momentum Breakout |
| Win rate target (qualitative) | High (60-72%) with 1:2.0 R:R payoff |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `kaufman-ready-set-go-momentum-official-source`
**Source type:** `verified_quantitative_model`
**Pointer:** `Kaufman, P. J. (2013). Trading Systems and Methods, 5th Edition. John Wiley & Sons.`
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41003_kaufman-ready-set-go-momentum.md`

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
| v1 | 2026-08-18 | Initial build from card | Task 8de78517-0995-43b1-9c4e-30e0a0f1b1df |
