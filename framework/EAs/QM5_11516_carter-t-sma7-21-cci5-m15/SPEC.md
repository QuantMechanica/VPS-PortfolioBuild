# QM5_11516_carter-t-sma7-21-cci5-m15 - Strategy Spec

**EA ID:** QM5_11516
**Slug:** carter-t-sma7-21-cci5-m15
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see strategy-seeds/sources/8794b680-f6f4-5142-b12c-e5e0057e7bcf/)
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The EA trades M15 trend following momentum using SMA(7) crossing SMA(21) synchronized with CCI(5) crossing zero. A long entry triggers when SMA(7) crosses above SMA(21) within the last 2 bars and CCI(5) crosses above zero within 1 bar of the SMA cross. A short entry mirrors with SMA(7) crossing below SMA(21) and CCI(5) crossing below zero within 1 bar. Initial stop loss is fixed at 15 pips. TP1 closes 50% of the position at 25 pips profit and moves stop loss to breakeven. The remaining 50% is closed when price closes back across SMA(7).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_sma_fast_period | 7 | 2-50 | Fast SMA period for crossover trigger. |
| strategy_sma_slow_period | 21 | 5-200 | Slow SMA period for crossover trigger. |
| strategy_cci_period | 5 | 2-50 | CCI period for zero-line momentum cross. |
| strategy_cross_lookback | 2 | 1-10 | Maximum lookback bars for the SMA cross event. |
| strategy_sync_bars | 1 | 0-5 | Maximum bar difference between SMA and CCI crosses. |
| strategy_sl_pips | 15 | 5-100 | Initial fixed stop loss in pips. |
| strategy_tp1_pips | 25 | 10-200 | First take profit distance in pips for 50% partial close. |
| strategy_partial_close_ratio | 0.50 | 0.1-0.9 | Position fraction closed at TP1. |
| strategy_be_buffer_pips | 0 | 0-20 | Additional profit buffer in pips when moving SL to BE. |
| strategy_spread_cap_pips | 12 | 1-50 | Maximum allowable spread in pips for entry. |
| strategy_no_friday_entry | true | true/false | Disallow new entries on Friday broker time. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major liquid FX pair with M15 history.
- GBPUSD.DWX - Major liquid FX pair with M15 history.
- USDJPY.DWX - Major liquid FX pair with M15 history.

**Explicitly NOT for:**
- Non-DWX symbols - V5 registry requires .DWX symbols.
- Indices and commodities - Strategy is designed for major liquid FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_M15) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 |
| Typical hold time | Intraday (hours) |
| Expected drawdown profile | Fixed 15-pip risk per trade with 17% max drawdown |
| Regime preference | Intraday trend following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, 'Forex Trend Following Strategies: 20 Trend Following Systems', System #12, self-published 2014.
**R1-R4 verdict (Q00):** all PASS per D:/QM/strategy_farm/artifacts/cards_approved/QM5_11516_carter-t-sma7-21-cci5-m15.md

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
| v1 | 2026-08-23 | Initial build from card | 53266c28-bd4a-4400-80da-dd621c2558ff |
