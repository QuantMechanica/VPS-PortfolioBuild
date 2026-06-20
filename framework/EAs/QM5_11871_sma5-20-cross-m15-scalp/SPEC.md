# QM5_11871_sma5-20-cross-m15-scalp - Strategy Spec

**EA ID:** QM5_11871
**Slug:** sma5-20-cross-m15-scalp
**Source:** 182e6755-015a-50ff-a0c9-b5507c5308b4 (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a simple SMA(5) and SMA(20) crossover on M15 forex charts. A long entry fires when SMA(5) crosses above SMA(20) on the last closed bar and SMA(20) is sloping upward; a short entry fires when SMA(5) crosses below SMA(20) and SMA(20) is sloping downward. Entries are market orders with fixed 5-pip stop loss and fixed 5-pip take profit. There is no discretionary exit or active trade management beyond the framework Friday close and central guard rails.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_sma_fast_period | 5 | >= 1 | Fast SMA period used for the crossover trigger. |
| strategy_sma_slow_period | 20 | >= 2 | Slow SMA period used for the crossover trigger and slope filter. |
| strategy_slope_lookback | 3 | >= 1 | Closed bars back used to confirm SMA20 slope direction. |
| strategy_slope_min_pips | 0.0 | >= 0.0 | Minimum SMA20 slope magnitude in pips; 0 means any non-flat slope qualifies. |
| strategy_sl_pips | 5 | >= 1 | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 5 | >= 1 | Fixed take-profit distance in pips. |
| strategy_spread_pct_of_stop | 50.0 | >= 0.0 | Blocks entries when positive modeled spread is wider than this percent of the stop distance. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid major forex pair for the SMA scalp.
- GBPUSD.DWX - card-listed liquid major forex pair for the SMA scalp.
- USDJPY.DWX - card-listed liquid major forex pair for the SMA scalp.
- AUDUSD.DWX - card-listed liquid major forex pair for the SMA scalp.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - the approved card targets a forex M15 SMA scalp only.
- Forex symbols outside the registered basket - they were not listed in the approved card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 80 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Scalping profile with many small fixed-risk wins and losses. |
| Regime preference | trend |
| Win rate target (qualitative) | medium-high, because 1:1 RR and spread costs require over 50% wins. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 182e6755-015a-50ff-a0c9-b5507c5308b4
**Source type:** local PDF archive
**Pointer:** Unknown author, My Top Three Scalping Trading Strategies, about 2020
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11871_sma5-20-cross-m15-scalp.md`

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
| v1 | 2026-06-20 | Initial build from card | 200da64a-fa4c-4671-bbf3-ca570b97cc19 |
