# QM5_1623_hopwood-bermaui-dss-h4 - Strategy Spec

**EA ID:** QM5_1623
**Slug:** hopwood-bermaui-dss-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

This EA implements the Steve Hopwood Bermaui Double-Smoothed Stochastic (DSS) mean-reversion strategy on H4 bars with a D1 EMA(200) trend regime filter.
DSS (Blau 1995) applies double EMA smoothing to the raw stochastic oscillator. The Bermaui methodology calculates rolling dynamic overbought/oversold bands based on mean and standard deviation over a lookback window.

- Long Entry: DSS rolls up from oversold, crossing back above the lower threshold while D1 price is above D1 EMA(200) and cooldown condition is met.
- Short Entry: DSS rolls down from overbought, crossing back below the upper threshold while D1 price is below D1 EMA(200) and cooldown condition is met.
- Exit: Opposite signal, time stop (max 10-20 H4 bars), or ATR-based TP / BE trailing.
- Protective Stop: Initial SL placed at 1.5 * ATR(14, H4).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_dss_stoch_period | 8 | 5-14 | DSS raw stochastic lookback (%K) |
| strategy_dss_inner_ema | 5 | 3-8 | DSS first EMA smoothing period |
| strategy_dss_outer_ema | 3 | 2-5 | DSS second EMA smoothing period |
| strategy_bermaui_lookback | 20 | 14-50 | Bermaui dynamic threshold lookback |
| strategy_bermaui_k | 1.8 | 1.5-2.5 | Bermaui std multiplier |
| strategy_min_overshoot_mult | 2.0 | 1.5-3.0 | Minimum overshoot gate in std deviations |
| strategy_d1_ema_period | 200 | 100-250 | D1 trend filter EMA period |
| strategy_atr_period | 14 | 10-20 | ATR period for stops and targets |
| strategy_atr_sl_mult | 1.5 | 1.0-3.0 | Stop loss multiplier in ATR |
| strategy_atr_tp_mult | 1.5 | 1.0-3.0 | Take profit multiplier in ATR |
| strategy_max_hold_bars | 10 | 5-30 | Time stop in H4 bars |
| strategy_cooldown_bars | 6 | 3-12 | Entry cooldown in H4 bars |
| strategy_be_atr_mult | 0.75 | 0.5-1.5 | Break-even trigger in ATR |
| strategy_spread_max_atr_mult | 0.3 | 0.1-0.5 | Max spread threshold in ATR |

---

## 3. Symbol Universe

**Baseline DWX symbols:**
- GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX, WS30.DWX
- XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, NZDUSD.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(200) |
| Bar gating | QM_IsNewBar() |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30-60 |
| Typical hold time | 2-10 H4 bars |
| Regime preference | Mean-reversion in trend direction |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** Steve Hopwood ForexFactory archive / William Blau 1995 (DSS)
**R1-R4 verdict (Q00):** all PASS; see docs/strategy_card.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | ,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | 0.5% |
