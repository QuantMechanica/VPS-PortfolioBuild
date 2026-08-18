# QM5_41001_keith-fitschen-aberration-trading-system — Strategy Spec

**EA ID:** QM5_41001
**Slug:** keith-fitschen-aberration-trading-system
**Source:** keith-fitschen-aberration-trading-system-official-source (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41001_keith-fitschen-aberration-trading-system.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy implements Keith Fitschen's Aberration Commodity Trend System, a multi-decade trend-following model utilizing 3.0-standard-deviation 30-day Bollinger Bands on the D1 timeframe. All calculations and breakout validations are performed strictly on the close of bar [1] (Shift = 1).

A Long entry is triggered when the previous closed bar's Close crosses above the 3.0 standard deviation Upper Bollinger Band (Close[1] > UpperBand[1] and Close[2] <= UpperBand[2]).

A Short entry is triggered when the previous closed bar's Close crosses below the 3.0 standard deviation Lower Bollinger Band (Close[1] < LowerBand[1] and Close[2] >= LowerBand[2]).

Stop Loss is initialized at 2.5× ATR(14, D1)[1] from the entry price. Position exit is dynamically governed by a trailing midline rule: open Long positions are closed when daily Close[1] falls below the 30-period SMA midline; open Short positions are closed when daily Close[1] rises above the 30-period SMA midline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | `D1` | Base execution and indicator timeframe |
| `strategy_sma_period` | `30` | `20-45` | Aberration SMA baseline lookback |
| `strategy_dev_multiplier` | `3.00` | `2.5-3.5` | Standard deviation expansion multiplier |
| `strategy_atr_period` | `14` | `10-20` | ATR period for volatility distance & spread filter |
| `strategy_atr_sl_mult` | `2.5` | `1.5-3.5` | Multiplier on ATR for stop loss placement |
| `strategy_tp_rr_mult` | `8.0` | `4.0-12.0` | Cap take profit multiplier for trend riding |
| `strategy_use_mid_exit` | `true` | `true/false` | Close position on 30 SMA midline cross |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` — Primary liquid energy commodity CFD with strong macro trend cycles
- `XAUUSD.DWX` — Precious metals commodity CFD exhibiting persistent trend breakouts
- `SP500.DWX` — US large cap equity index CFD with multi-week trend momentum

**Explicitly NOT for:**
- Mean-reverting noisy FX crosses without clear trend persistence

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | 2 weeks to 3 months |
| Expected drawdown profile | Moderate, < 8.5% Max Drawdown with trend riding |
| Regime preference | High Momentum / Strong Macro Trend Breakout |
| Win rate target (qualitative) | Moderate (50-65%) with high payoff ratio |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `keith-fitschen-aberration-trading-system-official-source`
**Source type:** `verified_quantitative_model`
**Pointer:** `Fitschen, K. (1993). Aberration Trading System. Futures Truth Magazine #1 All-Time System.`
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41001_keith-fitschen-aberration-trading-system.md`

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
| v1 | 2026-08-18 | Initial build from card | Task 9fbca489-f822-4412-8066-a819bc100eb7 |
