# QM5_11552_carter-t-m5-ema5-10-mtf4h-rsi-stoch-macd - Strategy Spec

**EA ID:** QM5_11552
**Slug:** carter-t-m5-ema5-10-mtf4h-rsi-stoch-macd
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on M5 when the H4 EMA(5) and EMA(10) define the trend direction. A long entry requires H4 EMA(5) above EMA(10), an M5 EMA(5) cross above EMA(10), RSI(14) above 50, Stochastic %K rising and below 80, and MACD main rising. A short entry mirrors those rules with H4 EMA(5) below EMA(10), an M5 bearish EMA cross, RSI(14) below 50, Stochastic %K falling and above 20, and MACD main falling. Exits are fixed 25-pip stop loss and fixed 25-pip take profit, plus the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_trend_tf | PERIOD_H4 | MT5 timeframe enum | Higher timeframe used for EMA trend filtering |
| strategy_ema_fast_period | 5 | 1+ | Fast EMA period for H4 trend and M5 entry cross |
| strategy_ema_slow_period | 10 | 2+ | Slow EMA period for H4 trend and M5 entry cross |
| strategy_rsi_period | 14 | 2+ | RSI period on M5 |
| strategy_rsi_mid | 50.0 | 0-100 | RSI midline threshold for long and short filters |
| strategy_stoch_k | 5 | 1+ | Stochastic %K period |
| strategy_stoch_d | 3 | 1+ | Stochastic %D period |
| strategy_stoch_slow | 3 | 1+ | Stochastic slowing |
| strategy_stoch_ob | 80.0 | 0-100 | Long entries require %K below this value |
| strategy_stoch_os | 20.0 | 0-100 | Short entries require %K above this value |
| strategy_macd_fast | 12 | 1+ | MACD fast EMA period |
| strategy_macd_slow | 26 | 2+ | MACD slow EMA period |
| strategy_macd_signal | 9 | 1+ | MACD signal period |
| strategy_sl_pips | 25.0 | 1+ | Fixed stop-loss distance in pips |
| strategy_tp_pips | 25.0 | 1+ | Fixed take-profit distance in pips |
| strategy_spread_pct_of_stop | 20.0 | 0+ | Spread cap as percent of the 25-pip stop distance, equivalent to 5 pips at defaults |
| strategy_no_friday_entry | true | true/false | Blocks fresh Friday entries per card |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - The card explicitly names EURUSD.DWX and the DWX matrix confirms it is available.

**Explicitly NOT for:**
- Non-EURUSD.DWX forex pairs - The approved card does not authorize pair expansion.
- Index and commodity `.DWX` symbols - The source strategy is a forex M5 setup, not an index or commodity strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H4 EMA(5) and EMA(10) trend filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Intraday, minutes to hours |
| Expected drawdown profile | Fixed 25-pip risk per trade with one-position framework duplicate protection |
| Regime preference | Short-term trend and momentum continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #11, self-published 2014
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11552_carter-t-m5-ema5-10-mtf4h-rsi-stoch-macd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | 0dfc14e7-fe69-49aa-87ed-c1d608357216 |
