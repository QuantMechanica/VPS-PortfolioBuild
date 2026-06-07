# QM5_11115_dpo-zero-ef - Strategy Spec

**EA ID:** QM5_11115
**Slug:** `dpo-zero-ef`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H4 bars. It computes a Detrended Price Oscillator as close minus a shifted SMA(14), using the source displacement floor(14 / 2) + 1. A long entry is opened when DPO crosses from zero or below to above zero; a short entry is opened when DPO crosses from zero or above to below zero. Longs close on a cross back below zero, shorts close on a cross back above zero, and either side closes after 15 H4 bars if no opposite cross has occurred.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dpo_period` | 14 | 2-200 | SMA period used by the DPO calculation. |
| `strategy_dpo_shift` | 8 | 1-100 | Source DPO shift, floor(period / 2) + 1 for the default period. |
| `strategy_atr_period` | 14 | 2-200 | ATR period used for initial stop distance. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-20.0 | Initial stop multiplier applied to ATR(14). |
| `strategy_max_hold_bars` | 15 | 1-200 | Maximum holding time in H4 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed in the card's Primary P2 basket and available in the DWX matrix.
- `GBPUSD.DWX` - listed in the card's Primary P2 basket and available in the DWX matrix.
- `USDJPY.DWX` - listed in the card's Primary P2 basket and available in the DWX matrix.
- `XAUUSD.DWX` - listed in the card's Primary P2 basket and available in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.

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
| Trades / year / symbol | `45` |
| Typical hold time | Up to 15 H4 bars, usually hours to a few days. |
| Expected drawdown profile | Moderate, controlled by fixed ATR stop and one active position per symbol/magic. |
| Regime preference | Zero-cross oscillator reversal or continuation, depending on symbol regime. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub indicator source`
**Pointer:** `https://github.com/EarnForex/Detrended-Price-Oscillator`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11115_dpo-zero-ef.md`

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
| v1 | 2026-06-07 | Initial build from card | 10a388ec-9fcf-41b1-b6eb-2e088f35d178 |
