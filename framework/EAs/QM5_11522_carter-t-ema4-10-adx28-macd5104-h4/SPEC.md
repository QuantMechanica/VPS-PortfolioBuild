# QM5_11522_carter-t-ema4-10-adx28-macd5104-h4 — Strategy Spec

**EA ID:** QM5_11522
**Slug:** carter-t-ema4-10-adx28-macd5104-h4
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see `strategy-seeds/sources/8794b680-f6f4-5142-b12c-e5e0057e7bcf/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H4 trend-following entries when EMA(4) crosses EMA(10) within the last three closed bars. A long requires +DI above -DI on ADX(28) and MACD(5,10,4) main above zero; a short requires -DI above +DI and MACD main below zero. Entries are sent at the next-bar market price with a fixed 35 pip stop and fixed source-specified take-profit distance. The card adds a 15 pip spread cap and forbids new Friday entries; normal Friday close, news, risk, and kill-switch handling remain framework-managed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 4 | 1-100 | Fast EMA period for the cross trigger. |
| strategy_ema_slow_period | 10 | 2-200 | Slow EMA period for the cross trigger. |
| strategy_cross_lookback | 3 | 1-10 | Number of closed bars in which the EMA cross may have occurred. |
| strategy_adx_period | 28 | 2-100 | ADX/DI period for directional confirmation. |
| strategy_adx_min | 0.0 | 0-100 | Optional ADX strength floor; 0 disables the floor per card baseline. |
| strategy_macd_fast | 5 | 1-100 | MACD fast EMA period. |
| strategy_macd_slow | 10 | 2-200 | MACD slow EMA period. |
| strategy_macd_signal | 4 | 1-100 | MACD signal period. |
| strategy_sl_pips | 35.0 | 1-40 | Fixed stop distance in pips. |
| strategy_tp_pips | 70.0 | 1-250 | Fixed take-profit distance in pips; setfiles use pair-specific H4 values. |
| strategy_spread_cap_pips | 15.0 | 0-50 | Blocks only genuinely wide modeled spread above this cap. |
| strategy_no_friday_entry | true | true/false | Blocks new entries on broker-time Friday. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — source-specified EUR/USD H4 instrument with 70 pip H4 target.
- GBPUSD.DWX — source-specified GBP/USD H4 instrument with 80 pip H4 target.
- USDJPY.DWX — source-specified USD/JPY H4 instrument with 80 pip H4 target.
- USDCHF.DWX — source-specified USD/CHF H4 instrument with 60 pip H4 target.

**Explicitly NOT for:**
- Index, commodity, and non-source FX symbols — the card only specifies the four FX pairs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | H4 trend trades, typically hours to several days |
| Expected drawdown profile | Trend-following whipsaw drawdown in ranging FX regimes |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #20, self-published 2014
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11522_carter-t-ema4-10-adx28-macd5104-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | 765ad6e9-e713-4344-a127-04d7aac901ed |
