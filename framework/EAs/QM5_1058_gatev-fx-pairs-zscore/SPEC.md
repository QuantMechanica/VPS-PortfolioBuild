# QM5_1058_gatev-fx-pairs-zscore - Strategy Spec

**EA ID:** QM5_1058
**Slug:** gatev-fx-pairs-zscore
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades two fixed FX pairs: EURUSD versus GBPUSD, and AUDUSD versus NZDUSD. On each D1 closed bar it estimates a 60-bar rolling OLS beta between log prices, computes the spread `log(A) - beta * log(B)`, and converts that spread to a 60-bar z-score. It opens a long pair when the z-score is below -2.0 and a short pair when the z-score is above +2.0, only when the 60-bar return correlation is above 0.6. It closes both legs when the absolute z-score is below 0.5, above 4.0, or the pair has been held for 20 D1 bar equivalents.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_bars` | 60 | 20+ | Rolling OLS, spread mean, spread standard deviation, and return-correlation lookback. |
| `strategy_entry_z` | 2.0 | >0 | Absolute z-score threshold for opening a pair trade. |
| `strategy_exit_z` | 0.5 | >0 | Absolute z-score threshold for mean-reversion close. |
| `strategy_hard_stop_z` | 4.0 | > entry z | Absolute z-score structural-break close. |
| `strategy_min_corr` | 0.6 | 0-1 | Minimum rolling return correlation required before opening. |
| `strategy_time_stop_bars` | 20 | 1+ | Maximum D1 bar-equivalent hold time before closing. |
| `strategy_max_spread_points` | 50 | 0+ | Maximum allowed spread points per leg; 0 disables this filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Pair A leg A, explicitly named by the approved card and present in the DWX matrix.
- `GBPUSD.DWX` - Pair A leg B, explicitly named by the approved card and present in the DWX matrix.
- `AUDUSD.DWX` - Pair B leg A, explicitly named by the approved card and present in the DWX matrix.
- `NZDUSD.DWX` - Pair B leg B, explicitly named by the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- `USDNOK.DWX` - optional Pair C leg from the card, skipped because it is not present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 2 |
| Typical hold time | Up to 20 D1 bars |
| Expected drawdown profile | Z-score structural-break exits bound diverging pair spreads. |
| Regime preference | Mean-revert with high rolling pair correlation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** encyclopedia entry backed by academic paper
**Pointer:** Quantpedia Pairs Trading entry and Gatev, Goetzmann, Rouwenhorst (2006)
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1058_gatev-fx-pairs-zscore.md`

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
| v1 | 2026-06-13 | Initial build from card | 47df779e-2f47-4204-ae59-703192fef6be |
