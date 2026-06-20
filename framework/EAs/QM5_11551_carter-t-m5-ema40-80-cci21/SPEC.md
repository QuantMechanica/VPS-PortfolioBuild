# QM5_11551_carter-t-m5-ema40-80-cci21 - Strategy Spec

**EA ID:** QM5_11551
**Slug:** carter-t-m5-ema40-80-cci21
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the Carter System #10 M5 EMA trend plus CCI zero-cross rule. A long signal requires EMA(40) above EMA(80) on the last closed M5 bar and CCI(21) crossing from below zero to zero or above. A short signal requires EMA(40) below EMA(80) and CCI(21) crossing from above zero to zero or below. Exits are the fixed 12-pip stop loss, fixed 12-pip take profit, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 40 | 1-500 | Fast EMA period for the trend state. |
| `strategy_ema_slow_period` | 80 | 2-500 | Slow EMA period for the trend state. |
| `strategy_cci_period` | 21 | 2-200 | CCI lookback used for the zero-line cross trigger. |
| `strategy_sl_pips` | 12 | 1-100 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 12 | 1-100 | Fixed take-profit distance in pips. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries during the broker Friday session. |
| `strategy_spread_cap_pips` | 5.0 | 0.0-50.0 | Blocks entries only when the live spread is wider than this pip cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card's R3 PASS section names EURUSD.DWX M5 as available and testable on DWX.

**Explicitly NOT for:**
- Other `.DWX` symbols - the approved card does not authorize a portable basket beyond EURUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | intraday, typically minutes to a few hours |
| Expected drawdown profile | frequent small fixed-risk wins and losses from symmetric 12-pip SL/TP |
| Regime preference | short-term trend continuation after oscillator reset |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", self-published 2014, System #10; local source attribution captured via `sources/carter-thomas-20-forex-strategies-5min`.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11551_carter-t-m5-ema40-80-cci21.md`.

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
| v1 | 2026-06-20 | Initial build from card | b986b60c-a828-4511-a64e-71f71b395bac |
