# QM5_11517_carter-t-ema5-15-50-100-macd-h4 - Strategy Spec

**EA ID:** QM5_11517
**Slug:** carter-t-ema5-15-50-100-macd-h4
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see strategy-seeds/sources/8794b680-f6f4-5142-b12c-e5e0057e7bcf/)
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The EA trades H4 trend following momentum using a 4-EMA ribbon (EMA 5, 15, 50, 100) and MACD(12,26,9) zero-line filter. A long setup triggers when EMA(5) crosses above EMA(15) within the last 3 bars, closed price is above both EMA(50) and EMA(100), and MACD main line is positive. A short setup mirrors with EMA(5) crossing below EMA(15) within 3 bars, closed price below both EMA(50) and EMA(100), and MACD main line negative. Fixed stop loss is set at 30 pips and fixed take profit is set at 60 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 5 | 2-50 | Fast EMA period for crossover trigger. |
| strategy_ema_slow_period | 15 | 5-100 | Slow EMA period for crossover trigger. |
| strategy_ema_trend1_period | 50 | 20-200 | Intermediate structural EMA trend filter. |
| strategy_ema_trend2_period | 100 | 50-500 | Long-term structural EMA trend filter. |
| strategy_macd_fast | 12 | 2-50 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 10-100 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 2-50 | MACD signal line period. |
| strategy_cross_lookback | 3 | 1-10 | Maximum lookback bars for the fast EMA cross. |
| strategy_sl_pips | 30 | 10-100 | Fixed stop loss in pips. |
| strategy_tp_pips | 60 | 20-200 | Fixed take profit in pips. |
| strategy_spread_cap_pips | 15 | 1-50 | Maximum allowable spread in pips for entry. |
| strategy_no_friday_entry | true | true/false | Disallow new entries on Friday broker time. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major liquid FX pair with H4 history.
- GBPUSD.DWX - Major liquid FX pair with H4 history.

**Explicitly NOT for:**
- Non-DWX symbols - V5 registry requires .DWX symbols.
- Minor/exotic pairs and CFDs - Strategy is tailored to major liquid FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_H4) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Swing (days) |
| Expected drawdown profile | Fixed 30-pip risk with 18% max drawdown |
| Regime preference | Multi-layered trend following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, 'Forex Trend Following Strategies: 20 Trend Following Systems', System #14, self-published 2014.
**R1-R4 verdict (Q00):** all PASS per D:/QM/strategy_farm/artifacts/cards_approved/QM5_11517_carter-t-ema5-15-50-100-macd-h4.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | ,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from card | df68e99a-096b-4875-b408-d64cf204f2b0 |
