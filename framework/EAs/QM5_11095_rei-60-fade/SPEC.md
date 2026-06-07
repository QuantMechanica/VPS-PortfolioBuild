# QM5_11095_rei-60-fade - Strategy Spec

**EA ID:** QM5_11095
**Slug:** `rei-60-fade`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates Tom DeMark's Range Expansion Index on completed bars. It opens long when REI(8) crosses back above -60 from below, and opens short when REI(8) crosses back below +60 from above. It skips a new same-side entry if the same-side crossing fired during the previous three bars. Open positions close on the opposite REI crossing or after ten bars, with the initial stop placed at 2.0 times ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rei_period` | 8 | 1+ | REI lookback period from the source default. |
| `strategy_rei_level` | 60.0 | >0 | Symmetric REI threshold used for +60 and -60 crossings. |
| `strategy_cooldown_bars` | 3 | 0+ | Bars checked for a prior same-side signal before a fresh entry. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier used for the initial stop. |
| `strategy_max_hold_bars` | 10 | 1+ | Maximum holding period in chart bars before strategy exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named in the approved R3 basket.
- `GBPUSD.DWX` - FX major named in the approved R3 basket.
- `USDJPY.DWX` - FX major named in the approved R3 basket.
- `XAUUSD.DWX` - liquid metal CFD named in the approved R3 basket.

**Explicitly NOT for:**
- Symbols outside the approved R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `28` |
| Typical hold time | `up to 10 H4 bars, about 40 hours` |
| Expected drawdown profile | `ATR-bounded oscillator reversal losses during persistent trends` |
| Regime preference | `mean-revert / oscillator reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub repository / MetaTrader indicator`
**Pointer:** `https://github.com/EarnForex/Range-Expansion-Index`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11095_rei-60-fade.md`

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
| v1 | 2026-06-07 | Initial build from card | 697ccf85-57c5-4076-9e1d-f82782d72a79 |
