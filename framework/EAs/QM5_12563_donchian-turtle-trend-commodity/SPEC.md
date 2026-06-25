<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_12563_donchian-turtle-trend-commodity — Strategy Spec

**EA ID:** QM5_12563
**Slug:** `donchian-turtle-trend-commodity`
**Source:** `2d4e7f91-3b6c-5a82-9e15-7c8b1f4a6d20` (see `strategy-seeds/sources/2d4e7f91-3b6c-5a82-9e15-7c8b1f4a6d20/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On each D1 bar close, the EA checks whether price has broken above the highest high of the prior 20 D1 bars (long entry) or below the lowest low of the prior 20 D1 bars (short entry). One position is held per magic; no pyramiding. The hard stop is placed at 2× ATR(20) from the market entry price. The position exits when the D1 close crosses back through the 10-bar reverse Donchian channel (close below the 10-day low for longs; close above the 10-day high for shorts), or when the 2N stop is hit. A volatility filter blocks new entries when ATR(20) falls below its 0.5th percentile over the trailing 252-day window (dead-volatility regime suppression). This is the original Turtle System 1 ruleset applied mechanically to commodity and metals CFDs on D1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_period` | 20 | 10–50 | Donchian channel lookback for breakout entry (D1 bars) |
| `strategy_exit_period` | 10 | 5–25 | Donchian channel lookback for trend exit (D1 bars) |
| `strategy_atr_period` | 20 | 10–30 | ATR period used to size the 2N stop distance |
| `strategy_atr_stop_mult` | 2.0 | 1.0–4.0 | Stop = ATR × multiple (N multiplier) |
| `strategy_vol_lookback` | 252 | 60–504 | Rolling ATR history window for percentile filter (days) |
| `strategy_vol_pct` | 0.5 | 0.0–5.0 | Minimum ATR percentile; entries suppressed below this value |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` — WTI crude oil; highly trending commodity with clear ATR-based volatility structure; slot 0
- `XAGUSD.DWX` — Silver; precious metal with strong trend episodes; historically responsive to Donchian breakouts; slot 1
- `XAUUSD.DWX` — Gold; major liquid commodity/metal; diversification within the metals sleeve; slot 2

**Explicitly NOT for:**
- Forex pairs — uncorrelated instrument class; commission/spread profile differs materially
- Equity indices — different volatility regime; ORB and momentum strategies are purpose-built for those

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `≈14` |
| Typical hold time | `Days to weeks (trend-following; 2N stop + 10-day exit)` |
| Expected drawdown profile | `Moderate; many small stops, few large winners (positive skew)` |
| Regime preference | `Trending / breakout` |
| Win rate target (qualitative) | `low (classic trend-following: win rate ~35–45%, large winners)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2d4e7f91-3b6c-5a82-9e15-7c8b1f4a6d20`
**Source type:** `book`
**Pointer:** `Curtis Faith, "Way of the Turtle" (2007); Richard Dennis / William Eckhardt Turtle Trading rules`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12563_donchian-turtle-trend-commodity.md`

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
| v1 | 2026-06-25 | Initial build from card | b0465cd5-0037-4762-8e12-4f84ddf732f4 |
