# QM5_11492_carter-t-bb-stoch-outside-reversal-m5 - Strategy Spec

**EA ID:** QM5_11492
**Slug:** `carter-t-bb-stoch-outside-reversal-m5`
**Source:** `b3b11449-1e72-5140-917b-c35b6253f1e7` (see `strategy-seeds/sources/b3b11449-1e72-5140-917b-c35b6253f1e7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades M5 mean reversion after a closed candle finishes outside the 20-period, 2-deviation Bollinger Band. It sells when the closed candle is above the upper band, Stochastic %K is above 80, and the candle closes bearish. It buys when the closed candle is below the lower band, Stochastic %K is below 20, and the candle closes bullish. Exits are fixed 10 pip stop loss and fixed 20 pip take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 15-25 | Bollinger Band lookback period. |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger Band standard deviation multiplier. |
| `strategy_stoch_k_period` | 5 | 3-14 | Stochastic %K period. |
| `strategy_stoch_d_period` | 3 | 1-10 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-10 | Stochastic slowing value. |
| `strategy_stoch_overbought` | 80.0 | 75.0-85.0 | Overbought threshold for short entries. |
| `strategy_stoch_oversold` | 20.0 | 15.0-25.0 | Oversold threshold for long entries. |
| `strategy_sl_pips` | 10 | 8-12 | Fixed stop loss in pips. |
| `strategy_tp_pips` | 20 | 15-30 | Fixed take profit in pips. |
| `strategy_spread_cap_pips` | 15 | 1-30 | Maximum allowed live spread in pips. |
| `strategy_no_friday_entry` | true | true/false | Suppress new entries on Fridays. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - M5 DWX forex major named in the approved card.
- `GBPUSD.DWX` - M5 DWX forex major named in the approved card.
- `USDJPY.DWX` - M5 DWX forex major named in the approved card.
- `USDCHF.DWX` - M5 DWX forex major named in the approved card.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must use the `.DWX` symbol universe.
- Non-FX index or commodity symbols - the approved card is scoped to M5 forex majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `minutes to hours` |
| Expected drawdown profile | `Small fixed-risk losses with 2:1 fixed reward-to-risk target.` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b3b11449-1e72-5140-917b-c35b6253f1e7`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", self-published 2014 (System #3)`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11492_carter-t-bb-stoch-outside-reversal-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | e3254576-ae1f-42bc-95b4-fd4dca80e5bd |
