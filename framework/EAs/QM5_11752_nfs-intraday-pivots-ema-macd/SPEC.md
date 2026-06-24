# QM5_11752_nfs-intraday-pivots-ema-macd - Strategy Spec

**EA ID:** QM5_11752
**Slug:** `nfs-intraday-pivots-ema-macd`
**Source:** `781e6542-cf6d-5b05-b351-2c769d7fb926` (see `strategy-seeds/sources/781e6542-cf6d-5b05-b351-2c769d7fb926/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades M5 candle closes that reclaim or reject daily pivot levels computed from the prior D1 bar. A long is opened when the prior closed M5 bar has reclaimed a support level after penetration and closed at least 3 pips back above it, EMA(9) is above EMA(18), and both H1 MACD lines are above zero. A short is opened when the prior closed M5 bar has rejected a resistance level after penetration and closed at least 3 pips back below it, EMA(9) is below EMA(18), and both H1 MACD lines are below zero. Stop loss is fixed 15 pips beyond the pivot level by default, and take profit is the next pivot level in the trade direction with a 20-pip minimum distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 9 | 2-100 | Fast M5 EMA used for short-term trend state. |
| `strategy_ema_slow_period` | 18 | 3-200 | Slow M5 EMA used for short-term trend state. |
| `strategy_macd_fast` | 12 | 2-100 | H1 MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | H1 MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | H1 MACD signal period. |
| `strategy_pivot_zone_pips` | 5.0 | 1.0-50.0 | Distance around a pivot that counts as penetration proximity. |
| `strategy_hold_above_pips` | 3.0 | 1.0-50.0 | Minimum close distance back beyond the pivot after penetration. |
| `strategy_sl_pips` | 15 | 1-300 | Fixed stop distance in pips. |
| `strategy_min_tp_pips` | 20 | 1-500 | Minimum take-profit distance if the next pivot is closer. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - card primary USD/CHF instrument and verified DWX forex symbol.
- `EURUSD.DWX` - card target major FX pair with M5 and H1 DWX data.
- `USDJPY.DWX` - card target major FX pair with M5 and H1 DWX data.
- `GBPUSD.DWX` - card target major FX pair with M5 and H1 DWX data.

**Explicitly NOT for:**
- `SP500.DWX` - index market, not part of the card's FX pivot basket.
- `XAUUSD.DWX` - metal market, not part of the card's FX pivot basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` for previous-day pivot levels; `PERIOD_H1` for MACD bias |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday; minutes to a few hours, bounded by SL/TP and Friday close |
| Expected drawdown profile | Moderate fixed-stop intraday FX drawdown profile |
| Regime preference | Pivot support/resistance bounce and rejection with EMA/MACD trend confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `781e6542-cf6d-5b05-b351-2c769d7fb926`
**Source type:** `book / PDF compilation`
**Pointer:** `452915895-9-Forex-Systems-pdf.pdf`, pages 31-35
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11752_nfs-intraday-pivots-ema-macd.md`

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
| v1 | 2026-06-25 | Initial build from card | 7eb9925c-9107-42a7-b093-b7b554c6b42a |
