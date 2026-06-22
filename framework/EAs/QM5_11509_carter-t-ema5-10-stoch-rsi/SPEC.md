# QM5_11509_carter-t-ema5-10-stoch-rsi - Strategy Spec

**EA ID:** QM5_11509
**Slug:** carter-t-ema5-10-stoch-rsi
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades H1 trend-following reversals in both directions. A long entry requires EMA(5) to cross above EMA(10) within the last three closed bars, Stochastic %K(14,3,3) to be rising and below 80, and RSI(14) to be above 50. A short entry mirrors the rule: EMA(5) crosses below EMA(10), Stochastic is falling and above 20, and RSI(14) is below 50. Exits are indicator-driven: close a long on an opposite EMA cross or RSI crossing below 50, and close a short on an opposite EMA cross or RSI crossing above 50.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 5 | 2-50 | Fast EMA period used for entry and exit crosses. |
| strategy_ema_slow_period | 10 | 3-100 | Slow EMA period used for entry and exit crosses. |
| strategy_cross_lookback | 3 | 1-10 | Closed bars over which an EMA cross event can trigger entry. |
| strategy_stoch_k | 14 | 3-50 | Stochastic %K period. |
| strategy_stoch_d | 3 | 1-20 | Stochastic %D period. |
| strategy_stoch_slowing | 3 | 1-20 | Stochastic slowing period. |
| strategy_stoch_overbought | 80.0 | 50-100 | Long entries require Stochastic below this ceiling. |
| strategy_stoch_oversold | 20.0 | 0-50 | Short entries require Stochastic above this floor. |
| strategy_rsi_period | 14 | 2-50 | RSI period. |
| strategy_rsi_midline | 50.0 | 1-99 | RSI regime and exit crossing level. |
| strategy_sl_pips | 30 | 1-500 | Fixed stop-loss distance in pips. |
| strategy_spread_cap_pips | 15 | 0-100 | Maximum modeled spread in pips; zero spread is allowed. |
| strategy_no_friday_entry | true | true/false | Blocks new entries on broker-time Friday. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed H1 FX major with DWX data available.
- GBPUSD.DWX - Card-listed H1 FX major with DWX data available.
- AUDUSD.DWX - Card-listed H1 FX major with DWX data available.

**Explicitly NOT for:**
- Index CFDs - Card specifies FX instruments only.
- Metals and energy CFDs - Card specifies FX instruments only.
- Non-DWX symbols - Pipeline backtests require canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Expected trade frequency | Frontmatter not specified; inferred as frequent H1 trend-following entries. |
| Typical hold time | Frontmatter not specified; indicator-driven exits imply hours to days. |
| Expected drawdown profile | Frontmatter not specified; fixed 30-pip stops cap single-trade loss under HR4 sizing. |
| Regime preference | Trend-following / momentum. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #4, self-published 2014.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11509_carter-t-ema5-10-stoch-rsi.md`.

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
| v1 | 2026-06-23 | Initial build from card | 67c5fa59-d7f7-42e8-9e75-fa6be5372856 |
