# QM5_38002_codetrading-macd-ema-trend-pullback — Strategy Spec

**EA ID:** QM5_38002
**Slug:** codetrading-macd-ema-trend-pullback
**Source:** codetrading-macd-ema-trend-pullback-official-source (see `strategy-seeds/sources/codetrading-macd-ema-trend-pullback/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy is a trend-following momentum pullback engine operating on the M15 timeframe. It filters the macro trend direction using the 200 EMA. In an established trend, it looks for pullbacks into the 50 EMA dynamic support/resistance zone, followed by an aggressive MACD histogram zero-line crossover in the direction of the dominant trend.

A Long entry is triggered when the previous closed bar's Close is above the 200 EMA, Low is less than or equal to the 50 EMA, and the MACD histogram crosses above zero (`MACD_Hist[1] > 0` and `MACD_Hist[2] <= 0`). A Short entry is triggered when Close is below the 200 EMA, High is greater than or equal to the 50 EMA, and the MACD histogram crosses below zero (`MACD_Hist[1] < 0` and `MACD_Hist[2] >= 0`).

Stop Loss is set to 1.5× ATR(14) from entry price. Take Profit is set to 2.0× SL distance (1:2.0 Risk:Reward ratio). Open positions are actively trailed using a 2.0× ATR trailing stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | `M5-H1` | Base execution and indicator timeframe |
| `strategy_trend_ema_period` | `200` | `100-300` | Macro trend baseline EMA period |
| `strategy_pullback_ema_period` | `50` | `20-60` | Pullback dynamic support/resistance EMA period |
| `strategy_fast_macd_period` | `12` | `8-16` | Fast EMA period for MACD |
| `strategy_slow_macd_period` | `26` | `20-35` | Slow EMA period for MACD |
| `strategy_signal_macd_period` | `9` | `5-14` | Signal SMA period for MACD |
| `strategy_atr_period` | `14` | `10-20` | ATR period for volatility and trailing stops |
| `strategy_atr_sl_mult` | `1.5` | `1.0-2.5` | Multiplier on ATR for stop loss placement |
| `strategy_tp_rr_mult` | `2.0` | `1.5-3.5` | Risk:Reward multiplier for take profit |
| `strategy_trailing_enabled` | `true` | `true/false` | Enable ATR-based trailing stop |
| `strategy_trail_atr_mult` | `2.0` | `1.0-3.0` | Multiplier on ATR for trailing stop distance |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — Primary US large-cap equity index with strong momentum trending characteristics
- `NDX.DWX` — Tech-heavy index with clean trend continuation patterns on M15
- `EURUSD.DWX` — Liquid FX major with reliable EMA pullback structures

**Explicitly NOT for:**
- Choppy sideways instruments with frequent whipsaws or wide spread products where M15 momentum is eroded

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | 2 hours to 12 hours |
| Expected drawdown profile | Moderate, < 3.5% Max Drawdown with asymmetric 1:2.0 R:R payoff |
| Regime preference | Trending / Momentum Pullback / Volatility Expansion |
| Win rate target (qualitative) | Medium-High (60-70%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-macd-ema-trend-pullback-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2021). MACD and EMA Trend Strategy: A Full Algorithmic Backtest in Python. YouTube.`
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38002_codetrading-macd-ema-trend-pullback.md`

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
| v1 | 2026-08-18 | Initial build from card | Task f0823eb2-3859-45a3-9fa4-a83cc44207ef |
