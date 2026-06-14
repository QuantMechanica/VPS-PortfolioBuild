# QM5_10902_carter-ema-macd - Strategy Spec

**EA ID:** QM5_10902
**Slug:** carter-ema-macd
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50 (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades EURUSD on H1 when a short EMA crosses a longer EMA and both momentum confirmations agree. A long entry requires EMA(6) to cross above EMA(23), MACD(30,60,30) main to be above zero, and Stochastic(5,3,3) %K to cross above %D on the last closed bar. A short entry mirrors that logic with EMA(6) crossing below EMA(23), MACD main below zero, and %K crossing below %D. Positions exit through a fixed 30-pip stop loss, fixed 50-pip take profit, and the V5 framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 6 | >=1 | Fast EMA period used for the entry cross. |
| `strategy_slow_ema_period` | 23 | >=1 | Slow EMA period used for the entry cross. |
| `strategy_macd_fast_period` | 30 | >=1 | MACD fast period. |
| `strategy_macd_slow_period` | 60 | >=1 | MACD slow period. |
| `strategy_macd_signal_period` | 30 | >=1 | MACD signal period. |
| `strategy_stoch_k_period` | 5 | >=1 | Stochastic %K period. |
| `strategy_stoch_d_period` | 3 | >=1 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | >=1 | Stochastic slowing value. |
| `strategy_stop_loss_pips` | 30 | >=1 | Fixed stop loss distance in pips. |
| `strategy_take_profit_pips` | 50 | >=1 | Fixed take profit distance in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source symbol EURUSD is available directly in the DarwinexZero matrix.

**Explicitly NOT for:**
- Other `.DWX` symbols - the approved card names EURUSD only and does not authorize a portable basket expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | hours |
| Expected drawdown profile | Fixed 30-pip stop, trend-following momentum confirmation limits churn. |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", 2014, Strategy #3, page 9.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10902_carter-ema-macd.md`

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
| v1 | 2026-06-14 | Initial build from card | 5ee74e97-a0c8-408c-b735-b158fab755bf |
