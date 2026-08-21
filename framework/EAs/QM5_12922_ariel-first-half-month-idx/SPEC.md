# QM5_12922_ariel-first-half-month-idx — Strategy Spec

**EA ID:** QM5_12922
**Slug:** ariel-first-half-month-idx
**Source:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Opens a long position on the first trading session of each calendar month (trading day T+1). Holds the position through the first 9 trading sessions of the month (T+1 through T+9). Exits the long position at the conclusion of trading day 9 (open of trading day 10), remaining in cash for the remainder of the month. The position is protected by an ATR(D1,14) * 3 hard stop loss below the entry price and standard Friday close / news filter controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period on D1 for hard stop loss distance calculation |
| `strategy_atr_stop_mult` | 3.0 | 1.0-5.0 | ATR multiplier for stop loss distance below entry price |
| `strategy_hold_trading_days` | 9 | 1-15 | Number of trading days in the month to hold the long position |
| `strategy_require_d1` | true | true/false | Requires D1 chart timeframe for daily bar execution |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `GDAXI.DWX` — Liquid European equity index CFD with full D1 history.
- `NDX.DWX` — Liquid US tech equity index CFD with full D1 history.
- `SP500.DWX` — Liquid US large-cap equity index CFD available for backtesting.
- `UK100.DWX` — Liquid UK equity index CFD with full D1 history.
- `WS30.DWX` — Liquid US industrial equity index CFD with full D1 history.

**Explicitly NOT for:**
- `XAUUSD.DWX` — Precious metals and non-equity assets do not share the equity intra-month cash flow cycle.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | 9 trading days (~13 calendar days) |
| Expected drawdown profile | Moderate seasonal drawdown bounded by ATR(14)*3 stop |
| Regime preference | Monthly seasonal equity index cash-flow anomaly |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** paper
**Pointer:** Ariel, R.A. (1987) "A Monthly Effect in Stock Returns." Journal of Financial Economics 18(1), pp. 161-174
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12922_ariel-first-half-month-idx.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-21 | Initial build from card | 11468a5a-89fc-4872-b6ec-2a78250ae792 |
