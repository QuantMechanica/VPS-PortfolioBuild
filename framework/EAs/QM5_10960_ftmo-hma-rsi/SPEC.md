# QM5_10960_ftmo-hma-rsi — Strategy Spec

**EA ID:** QM5_10960
**Slug:** ftmo-hma-rsi
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA evaluates closed H4 bars. It buys when RSI(14) has been below 30 within the last five closed H4 bars, crosses back above 30, and HMA(20) crosses above HMA(50) on the current or prior two closed H4 bars. It sells the mirrored setup from above 70 with a bearish HMA cross. Each trade uses a volatility stop equal to 1.2 times the 60-day average daily range, a 2.0R take profit, an opposite HMA-cross exit, and a 30 H4-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | 2-100 | RSI lookback on H4 closes. |
| strategy_rsi_oversold | 30.0 | 1-50 | Long-side RSI recovery threshold. |
| strategy_rsi_overbought | 70.0 | 50-99 | Short-side RSI recovery threshold. |
| strategy_rsi_lookback_bars | 5 | 1-20 | Closed H4 bars checked for the prior RSI extreme. |
| strategy_hma_fast_period | 20 | 4-200 | Fast HMA period on H4. |
| strategy_hma_slow_period | 50 | 5-300 | Slow HMA period on H4. |
| strategy_hma_cross_lookback_bars | 3 | 1-10 | Closed H4 bars allowed for the confirming HMA cross. |
| strategy_adr_days | 60 | 10-252 | Daily bars used for the average daily range stop. |
| strategy_stop_adr_mult | 1.2 | 0.1-5.0 | Multiplier applied to the 60-day ADR stop. |
| strategy_take_profit_r | 2.0 | 0.5-5.0 | Take-profit distance in multiples of initial risk. |
| strategy_time_exit_h4_bars | 30 | 1-200 | Maximum holding period measured in H4 bars. |
| strategy_max_spread_stop_pct | 8.0 | 0.1-50.0 | Blocks entries when spread exceeds this percent of planned stop distance. |
| strategy_vol_percentile_years | 3 | 1-10 | Years of daily ADR samples used for the volatility-percentile filter. |
| strategy_min_vol_percentile | 20.0 | 0-100 | Blocks trading when 60-day ADR is below this percentile. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — liquid major FX pair in the card's R3 P2 basket.
- GBPUSD.DWX — liquid major FX pair in the card's R3 P2 basket.
- USDJPY.DWX — liquid major FX pair in the card's R3 P2 basket.
- XAUUSD.DWX — liquid metal symbol in the card's R3 P2 basket.

**Explicitly NOT for:**
- SP500.DWX — not in this card's FX/metals basket.
- NDX.DWX — not in this card's FX/metals basket.
- WS30.DWX — not in this card's FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 average daily range and D1 volatility percentile filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Up to 30 H4 bars, with earlier SL/TP or HMA-cross exits |
| Expected drawdown profile | Volatility-sized stop with fixed $1,000 backtest risk per trade |
| Regime preference | Momentum-reversal with adequate daily volatility |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog article
**Pointer:** https://ftmo.com/en/blog/effective-risk-management-using-volatility-and-technical-indicators/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10960_ftmo-hma-rsi.md`

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
| v1 | 2026-06-06 | Initial build from card | ac8ad4c0-7aa8-4b62-ae65-acf183a9536b |
