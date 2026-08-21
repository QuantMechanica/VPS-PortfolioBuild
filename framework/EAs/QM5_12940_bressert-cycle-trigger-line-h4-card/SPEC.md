# QM5_12940_bressert-cycle-trigger-line-h4-card — Strategy Spec

**EA ID:** QM5_12940
**Slug:** bressert-cycle-trigger-line-h4-card
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Gemini
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

The Bressert Cycle-Trigger-Line on DSS strategy operates on H4 bars. It evaluates Walter Bressert's Double-Smoothed Stochastic (DSS) with a 3-bar Simple Moving Average (SMA) trigger line.

A bullish entry occurs when DSS crosses above the trigger line while in the oversold zone (< 30.0), confirmed by D1 close > EMA(50) trend filter and H4 momentum confirmation (closed bar is bullish and closes above the prior 5-bar high). A bearish entry occurs on the mirror conditions (DSS crosses below trigger in overbought > 70.0 zone, D1 close < EMA(50), bearish H4 bar closing below prior 5-bar low).

Risk management uses ATR(14)-based stop loss (1.5x ATR from signal bar extreme), ATR profit target (1.5x ATR), trailing stop after partial target attainment, a 24-bar time stop, and an opposite-direction crossover exit signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_dss_stoch_period | 13 | 8-21 | DSS raw stochastic lookback (%K) |
| strategy_dss_inner_ema | 8 | 5-13 | DSS first EMA smoothing period |
| strategy_dss_outer_ema | 8 | 5-13 | DSS second EMA smoothing period |
| strategy_trigger_period | 3 | 2-5 | Trigger line SMA period on DSS |
| strategy_dss_os_zone | 30.0 | 20-35 | Oversold zone gate for BUY entries |
| strategy_dss_ob_zone | 70.0 | 65-80 | Overbought zone gate for SELL entries |
| strategy_d1_ema_period | 50 | 21-100 | Higher-TF D1 trend filter EMA period |
| strategy_momentum_window | 5 | 3-8 | Lookback window for prior bar extremes |
| strategy_atr_period | 14 | 10-21 | ATR period for stops and targets |
| strategy_atr_sl_mult | 1.5 | 1.0-2.5 | Stop loss distance in ATR multiples |
| strategy_atr_tp_mult | 1.5 | 1.0-3.0 | Take profit distance in ATR multiples |
| strategy_trail_atr_mult | 1.0 | 0.5-2.0 | Trailing stop distance in ATR multiples |
| strategy_max_hold_bars | 24 | 18-36 | Maximum hold duration in H4 bars |
| strategy_cooldown_bars | 12 | 6-18 | Minimum bars between entries in same direction |
| strategy_spread_max_atr_mult | 0.3 | 0.2-0.5 | Max allowed spread as fraction of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — DAX 40 index CFD
- `NDX.DWX` — Nasdaq 100 index CFD
- `SP500.DWX` — S&P 500 index CFD
- `UK100.DWX` — FTSE 100 index CFD
- `WS30.DWX` — Dow 30 index CFD
- `XAUUSD.DWX` — Gold commodity CFD
- `EURUSD.DWX` — FX major
- `GBPUSD.DWX` — FX major
- `USDJPY.DWX` — FX major
- `USDCHF.DWX` — FX major
- `AUDUSD.DWX` — FX major
- `USDCAD.DWX` — FX major
- `NZDUSD.DWX` — FX major

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 (EMA 50 trend filter) |
| Bar gating | `QM_IsNewBar(_Symbol, _Period)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15-35 |
| Typical hold time | 1-4 days (max 24 H4 bars) |
| Expected drawdown profile | Well-contained swings with ATR stop loss and time decay exits |
| Regime preference | Mean reversion in cycle turns aligned with macro daily trend |
| Win rate target (qualitative) | Medium (50-60%) |

---

## 6. Source Citation

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** published book / forum
**Pointer:** Walter Bressert — The Power of Oscillator/Cycle Combinations (1991 ch.3 / 1995 ch.4) + FF thread/187693 & 277401
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12940_bressert-cycle-trigger-line-h4-card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
