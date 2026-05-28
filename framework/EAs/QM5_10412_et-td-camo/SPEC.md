# QM5_10412_et-td-camo - Strategy Spec

**EA ID:** QM5_10412
**Slug:** `et-td-camo`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades TD Camouflage reversal bars on H1. A long signal occurs when the last closed bar makes the lowest low of the lookback, closes below the prior close, closes at or above its open, and finishes above the configured fraction of its own range. A short signal mirrors this at the highest high of the lookback, with the bar closing above the prior close, at or below its open, and below the configured range fraction. The stop uses the source percent adjustment from the signal low or high, the target is 1.5R, and exits also occur after 12 bars or on an opposite signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ll_lookback` | 5 | 1-50 | Bars used to confirm the signal bar is the lowest low for long entries. |
| `strategy_hh_lookback` | 5 | 1-50 | Bars used to confirm the signal bar is the highest high for short entries. |
| `strategy_stop_percent` | 3.0 | 0.1-20.0 | Percent adjustment applied to the signal low or high for the source stop. |
| `strategy_close_location` | 0.50 | 0.10-0.90 | Fraction of the bar range used for the close-location reversal test. |
| `strategy_target_rr` | 1.50 | 0.5-5.0 | Profit target as a multiple of initial risk. |
| `strategy_max_hold_bars` | 12 | 1-100 | Maximum bars to hold before strategy exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 includes this liquid FX major for portable OHLC reversal testing.
- `GBPUSD.DWX` - Card R3 includes this liquid FX major for portable OHLC reversal testing.
- `XAUUSD.DWX` - Card R3 includes gold, where range-location reversal bars are directly measurable.
- `GDAXI.DWX` - DWX matrix DAX symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - Card R3 includes Nasdaq 100 index CFD exposure.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol tick source is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | `up to 12 H1 bars` |
| Expected drawdown profile | Percent stops can be wide, especially on metals and indices; P3 should test ATR-normalized stops. |
| Regime preference | mean-revert reversal after fresh short lookback extremes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/t-demark-s-trend-lines.135311/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10412_et-td-camo.md`

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
| v1 | 2026-05-25 | Initial build from card | 4f2301e7-9c90-408d-9e3e-a0f562b4a67e |
