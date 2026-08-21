# QM5_38008_codetrading-optimized-bollinger-trend-breakout — Strategy Spec

**EA ID:** QM5_38008
**Slug:** codetrading-optimized-bollinger-trend-breakout
**Source:** codetrading-optimized-bollinger-trend-breakout-official-source (see `strategy-seeds/sources/codetrading-optimized-bollinger-trend-breakout/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy is a daily trend-following breakout system combining 2.5-sigma Bollinger Bands (20, 2.50) and a 200-period Exponential Moving Average (EMA 200) trend filter on the D1 timeframe. All calculations and breakout validations are performed strictly on the close of bar [1] (Shift = 1).

A Long entry is triggered when the previous closed bar's Close breaks above the Upper Bollinger Band (Close[1] > UpperBB[1]), the 200 EMA exhibits upward slope (EMA(200)[1] > EMA(200)[5]), and the candle is bullish (Close[1] > Open[1]).

A Short entry is triggered when the previous closed bar's Close breaks below the Lower Bollinger Band (Close[1] < LowerBB[1]), the 200 EMA exhibits downward slope (EMA(200)[1] < EMA(200)[5]), and the candle is bearish (Close[1] < Open[1]).

Stop Loss is set at 2.0× ATR(14, D1)[1] from the entry price. Position exit is dynamically governed by a trailing midline rule: open Long positions are closed when daily Close[1] falls below the 20-period SMA midline; open Short positions are closed when daily Close[1] rises above the 20-period SMA midline. Open positions also move to Break-Even (+2 points buffer) once floating profit reaches +1.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | `H4-D1` | Base execution and indicator timeframe |
| `strategy_bb_period` | `20` | `14-30` | Bollinger Bands period |
| `strategy_bb_dev` | `2.50` | `2.0-3.0` | Standard deviation expansion multiplier |
| `strategy_trend_ema_period` | `200` | `100-300` | Macro trend baseline EMA period |
| `strategy_trend_slope_lookback` | `5` | `3-10` | Lookback bars for EMA slope calculation |
| `strategy_atr_period` | `14` | `10-20` | ATR period for volatility distance & spread filter |
| `strategy_atr_sl_mult` | `2.0` | `1.5-3.0` | Multiplier on ATR for stop loss placement |
| `strategy_tp_rr_mult` | `5.0` | `3.0-8.0` | Cap take profit multiplier for trend riding |
| `strategy_use_mid_exit` | `true` | `true/false` | Close position on 20 SMA midline cross |
| `strategy_be_enabled` | `true` | `true/false` | Enable moving stop loss to break-even |
| `strategy_be_trigger_r` | `1.0` | `0.5-2.0` | Profit in R-multiples to trigger break-even move |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — Primary US Large Cap equity index CFD with robust trend persistence on D1
- `NDX.DWX` — High-beta US Tech index CFD well-suited for D1 momentum breakout expansion
- `XTIUSD.DWX` — Liquid energy commodity CFD exhibiting strong multi-week trend runs

**Explicitly NOT for:**
- Mean-reverting range-bound FX crosses with high noise on daily timeframe

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
| Typical hold time | 5 days to 4 weeks |
| Expected drawdown profile | Moderate, < 8% Max Drawdown with trend riding |
| Regime preference | High Momentum / Strong Trend Breakout |
| Win rate target (qualitative) | Moderate to High (55-65%) with high payoff ratio |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-optimized-bollinger-trend-breakout-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2022). Optimizing Rayner Teo's Bollinger Bands Strategy for Better Results. YouTube.`
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38008_codetrading-optimized-bollinger-trend-breakout.md`

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
| v1 | 2026-08-18 | Initial build from card | Task 1f82ac59-1c1e-4e72-a1f8-4eaea2120347 |
