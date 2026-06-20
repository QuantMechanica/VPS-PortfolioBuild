# QM5_11546_carter-t-m5-macd1226-stoch533-ema5oc - Strategy Spec

**EA ID:** QM5_11546
**Slug:** carter-t-m5-macd1226-stoch533-ema5oc
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the M5 Carter System #1 rule on EURUSD.DWX. A long entry fires when Stochastic K crosses up through 20 from the prior closed bar, MACD(12,26,1) main is higher than the prior closed bar, the signal candle is bullish, and EMA(5, close) is above EMA(5, open). A short entry mirrors the rule through the 80 Stochastic level, falling MACD, a bearish signal candle, and EMA(5, close) below EMA(5, open). Positions exit when EMA(5, close) crosses back to the opposite side of EMA(5, open), or by the 20-pip stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M5 | M1-D1 practical | Signal timeframe from the approved card. |
| strategy_ema_period | 5 | 2-50 | EMA period used for the close/open micro-channel. |
| strategy_macd_fast | 12 | 2-50 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 3-100 | MACD slow EMA period. |
| strategy_macd_signal | 1 | 1-30 | MACD signal period; card default is 1. |
| strategy_stoch_k | 5 | 2-50 | Stochastic K period. |
| strategy_stoch_d | 3 | 1-20 | Stochastic D period. |
| strategy_stoch_slowing | 3 | 1-20 | Stochastic slowing. |
| strategy_stoch_oversold | 20.0 | 0-50 | Long recovery threshold. |
| strategy_stoch_overbought | 80.0 | 50-100 | Short recovery threshold. |
| strategy_stop_pips | 20 | 1-25 | Fixed stop-loss distance in pips; P2 cap is 25 pips. |
| strategy_spread_cap_pips | 5 | 0-50 | Maximum modeled spread in pips; zero spread remains tradeable. |
| strategy_skip_friday_entry | true | true/false | Suppresses new Friday entries per card filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - The card explicitly names EURUSD.DWX and R3 confirms M5 DWX availability.

**Explicitly NOT for:**
- Non-EURUSD symbols - The approved card does not authorize portability beyond EURUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | intraday M5 holds, normally minutes to hours |
| Expected drawdown profile | frequent small fixed-stop losses with indicator exits on EMA channel reversals |
| Regime preference | short-term momentum recovery |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #1; `sources/carter-thomas-20-forex-strategies-5min`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11546_carter-t-m5-macd1226-stoch533-ema5oc.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | c4e02594-9de6-42dd-8abd-096ee02453c6 |
