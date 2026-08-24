# QM5_1623_hopwood-bermaui-dss-h4 - Strategy Spec

**EA ID:** QM5_1623
**Slug:** hopwood-bermaui-dss-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Development
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

This EA implements the approved Steve Hopwood Bermaui Double-Smoothed Stochastic
(DSS) mean-reversion strategy on completed H4 bars with a D1 EMA(200) trend
regime filter. DSS (Blau 1995) applies two EMA smoothing layers to the raw
stochastic oscillator. Bermaui overbought and oversold bands are the nearest-rank
80th and 20th percentiles of DSS over the latest 100 completed H4 bars.

- Long entry: DSS(10,5,5) crosses above the rolling 20th-percentile band while
  completed D1 price is above D1 EMA(200) and the six-H4-bar cooldown permits.
- Short entry: DSS(10,5,5) crosses below the rolling 80th-percentile band while
  completed D1 price is below D1 EMA(200) and the cooldown permits.
- Exit: capture exit at the opposite percentile band, fresh opposite-direction
  entry signal, D1 EMA(200) regime invalidation, or a 20-H4-bar time stop.
- Protective stop: initial SL at 2.0 * ATR(14, H4). The baseline has no take-profit
  and no break-even or trailing-stop overlay.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_dss_stoch_period | 10 | 7, 10, 14, 21 | DSS raw stochastic lookback (%K) |
| strategy_dss_inner_ema | 5 | card grid | DSS first EMA smoothing period |
| strategy_dss_outer_ema | 5 | card grid | DSS second EMA smoothing period |
| strategy_bermaui_lookback | 100 | 50, 100, 200 | Rolling completed-H4 DSS window |
| strategy_overbought_percentile | 80 | 70, 75, 80, 85 | Upper nearest-rank percentile |
| strategy_oversold_percentile | 20 | 15, 20, 25, 30 | Lower nearest-rank percentile |
| strategy_d1_ema_period | 200 | 100, 200 | D1 trend filter EMA period |
| strategy_atr_period | 14 | fixed baseline | ATR period for protective stop |
| strategy_atr_sl_mult | 2.0 | 1.5, 2.0, 2.5 | Initial stop multiplier in ATR |
| strategy_max_hold_bars | 20 | 15, 20, 30 | Time stop in H4 bars |
| strategy_cooldown_bars | 6 | fixed baseline | Same-direction cooldown in H4 bars |
| strategy_spread_max_atr_mult | 0.3 | fixed baseline | Maximum spread in ATR units |

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
| Typical hold time | Up to 20 H4 bars |
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
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | 0.5% |
