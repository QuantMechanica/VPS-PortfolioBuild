# QM5_11415_winning-pips-psar-ao-ac-h1 - Strategy Spec

**EA ID:** QM5_11415
**Slug:** `winning-pips-psar-ao-ac-h1`
**Source:** `2d83a162-c6c1-57a6-b325-3c5c9ddb618c` (see `strategy-seeds/sources/2d83a162-c6c1-57a6-b325-3c5c9ddb618c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-24

---

## 1. Strategy Logic

The EA trades H1 closed-bar confluence from PSAR, Awesome Oscillator, and Accelerator Oscillator. A long entry opens when PSAR is below the signal candle close, AO is rising versus the prior bar, and AC is rising versus the prior bar. A short entry opens when PSAR is above the signal candle close, AO is falling, and AC is falling. The stop is the signal candle low for longs or high for shorts, capped at 40 pips for P2, and the take profit is 2 times the stop distance. An open trade exits early when AO and AC both flip to the opposite colour on the same closed bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_psar_step` | 0.02 | 0.01-0.03 P3 sweep | PSAR acceleration step. |
| `strategy_psar_max` | 0.20 | 0.15-0.25 P3 sweep | PSAR maximum acceleration. |
| `strategy_ao_fast_period` | 5 | fixed by card | Fast SMA period for AO on median price. |
| `strategy_ao_slow_period` | 34 | fixed by card | Slow SMA period for AO on median price. |
| `strategy_ac_smooth_period` | 5 | fixed by card | AO smoothing period used for AC. |
| `strategy_tp_rr` | 2.0 | 1.5-2.5 P3 sweep | Take-profit multiple of stop distance. |
| `strategy_sl_cap_pips` | 40 | fixed P2 cap | Maximum initial stop distance in pips. |
| `strategy_spread_cap_pips` | 20 | fixed by card | Maximum positive spread before entries are blocked. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed H1 FX major with DWX data available.
- `GBPUSD.DWX` - Card-listed H1 FX major with DWX data available.
- `GBPJPY.DWX` - Card-listed H1 FX cross with DWX data available.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The approved card names only the three FX instruments above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | momentum trend confluence, inferred from card body |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2d83a162-c6c1-57a6-b325-3c5c9ddb618c`
**Source type:** anonymous website PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\481462063-Winning-Pips-System-4-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11415_winning-pips-psar-ao-ac-h1.md`

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
| v1 | 2026-06-24 | Initial build from card | fae9d0bc-338b-476c-a6ab-094b33afe744 |
