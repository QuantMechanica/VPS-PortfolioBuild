# QM5_11559_carter-t-m5-ema3-bb203-macd - Strategy Spec

**EA ID:** QM5_11559
**Slug:** carter-t-m5-ema3-bb203-macd
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades EURUSD.DWX on M5 when EMA(3) crosses the Bollinger Bands(20,3) middle band on the last closed bar. A long entry requires EMA(3) to cross from at or below the middle band to above it, with MACD(12,26,9) main greater than negative one pip from zero; a short entry requires the inverse cross with MACD main less than positive one pip from zero. Entries are market orders with a 12 pip stop loss and a 1:1 take profit. The EA does not add discretionary exits beyond fixed SL/TP and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 3 | 1 or higher | EMA period for the trigger leg. |
| strategy_bb_period | 20 | 2 or higher | Bollinger middle-band period. |
| strategy_bb_deviation | 3.0 | greater than 0 | Bollinger deviation multiplier. |
| strategy_macd_fast | 12 | 1 or higher | MACD fast EMA period. |
| strategy_macd_slow | 26 | greater than fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1 or higher | MACD signal period. |
| strategy_macd_zero_tol_pips | 1.0 | 0 or higher | MACD zero-approach tolerance, in pips. |
| strategy_sl_pips | 12 | 1 to 15 for P2 cap | Fixed stop-loss distance in pips. |
| strategy_tp_rr | 1.0 | greater than 0 | Take-profit distance as a multiple of stop risk. |
| strategy_no_friday_entry | true | true or false | Suppress new entries on Friday. |
| strategy_spread_cap_pips | 5 | 0 or higher | Skip entry when live spread is wider than this cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card explicitly names EURUSD.DWX as the M5 test instrument and it is present in the DWX symbol matrix.

**Explicitly NOT for:**
- Other DWX symbols - not registered for this build because the approved card only lists EURUSD.DWX and the R3 row does not narrate a wider portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Card does not specify; M5 12-pip SL/TP implies short intraday holds. |
| Expected drawdown profile | Card does not specify; fixed 1:1 SL/TP momentum entries. |
| Regime preference | Momentum resumption around the Bollinger middle band. |
| Win rate target (qualitative) | Card does not specify. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #20; artifacts/cards_approved/QM5_11559_carter-t-m5-ema3-bb203-macd.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per artifacts/cards_approved/QM5_11559_carter-t-m5-ema3-bb203-macd.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | ce19e715-45cc-49eb-b9df-4d4b3de82548 |
