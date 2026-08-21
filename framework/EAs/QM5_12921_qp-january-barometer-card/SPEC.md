# QM5_12921_qp-january-barometer-card — Strategy Spec

**EA ID:** QM5_12921
**Slug:** qp-january-barometer-card
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Evaluates the total return of January on equity indices. If the January return (calculated from the initial January session to the final January session close) is strictly positive, opens a long position on the first trading session of February. Holds the position through the remainder of the calendar year, exiting at the end of December (start of January). If January return is zero or negative, the EA remains in cash for the year. Protected by an ATR(D1,20) * 3 hard stop loss below the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 5-50 | ATR period on D1 for hard stop loss calculation |
| `strategy_atr_stop_mult` | 3.0 | 1.0-5.0 | ATR multiplier for stop loss distance below entry price |
| `strategy_require_d1` | true | true/false | Requires D1 chart timeframe for daily bar execution |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `SP500.DWX` — US large-cap equity index CFD available for backtesting (primary).
- `NDX.DWX` — Liquid US tech equity index CFD with full D1 history.
- `WS30.DWX` — Liquid US industrial equity index CFD with full D1 history.
- `GDAXI.DWX` — Liquid European equity index CFD with full D1 history.
- `UK100.DWX` — Liquid UK equity index CFD with full D1 history.

**Explicitly NOT for:**
- `XAUUSD.DWX` — Commodities do not participate in annual equity index barometer seasonality.

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
| Trades / year / symbol | 2 |
| Typical hold time | 11 months (~330 calendar days) |
| Expected drawdown profile | Low-frequency long-term equity market holding drawdown |
| Regime preference | Annual equity index calendar / return-sign timing |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7ede58dd-d184-5099-9d48-7a65de230853`
**Source type:** paper
**Pointer:** Quantpedia "January Barometer" / Cooper, McConnell, and Ovtchinnikov
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12921_qp-january-barometer-card.md`

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
| v1 | 2026-08-21 | Initial build from card | 63c95ae9-d593-403a-928b-c51ac9848a1b |
