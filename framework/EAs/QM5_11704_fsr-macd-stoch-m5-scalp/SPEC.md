# QM5_11704_fsr-macd-stoch-m5-scalp - Strategy Spec

**EA ID:** QM5_11704
**Slug:** `fsr-macd-stoch-m5-scalp`
**Source:** `9c37bc30-46e8-5965-bc24-a8eba30ed51f` (see `sources/fsr-m1-m5-macd-stoch-scalp`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades an M5 MACD and Stochastic scalping rule. A long setup requires MACD(12,26,9) main to be above zero on the last closed M5 bar and Stochastic %K(8,3,3) to cross back above 20 from oversold. A short setup requires MACD main to be below zero and Stochastic %K to cross back below 80 from overbought. Entries are market orders on the next bar; exits are only the fixed take profit, ATR stop loss, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 1-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 2-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period. |
| `strategy_stoch_k` | 8 | 1-100 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-50 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-50 | Stochastic slowing period. |
| `strategy_stoch_oversold` | 20.0 | 0-50 | Long trigger level crossed upward. |
| `strategy_stoch_overbought` | 80.0 | 50-100 | Short trigger level crossed downward. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stop placement. |
| `strategy_sl_atr_mult` | 2.0 | 0.1-10.0 | Stop distance multiplier on ATR. |
| `strategy_tp_pips` | 25 | 1-500 | Fixed take-profit distance in pips. |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Blocks only genuinely wide spread relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target symbol and verified DWX forex symbol.
- `GBPUSD.DWX` - card target symbol and verified DWX forex symbol.

**Explicitly NOT for:**
- Non-DWX symbols - V5 backtests require registered `.DWX` symbols.
- Non-forex index or commodity symbols - the source and card target FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` framework gate; signal readers use `PERIOD_M5` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 350 |
| Typical hold time | intraday, usually minutes to hours |
| Expected drawdown profile | scalping drawdowns driven by whipsaw clusters around noisy MACD/Stochastic reversals |
| Regime preference | short-term trend continuation with oscillator pullback reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9c37bc30-46e8-5965-bc24-a8eba30ed51f`
**Source type:** self-published PDF
**Pointer:** `sources/fsr-m1-m5-macd-stoch-scalp`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11704_fsr-macd-stoch-m5-scalp.md`

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
| v1 | 2026-06-20 | Initial build from card | 4ce84299-2838-4877-b863-f845c4ced592 |
