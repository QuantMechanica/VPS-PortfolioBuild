# QM5_1058_gatev-fx-pairs-zscore - Strategy Spec

**EA ID:** QM5_1058
**Slug:** `gatev-fx-pairs-zscore`
**Source:** `7ede58dd-d184-5099-9d48-7a65de230853` (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades two fixed FX pairs: EURUSD versus GBPUSD, and AUDUSD versus NZDUSD. On each D1 close it estimates a 60-bar rolling OLS beta between the two log-price series, computes the beta-adjusted spread z-score, and opens a two-leg mean-reversion trade when the spread is beyond +/-2.0 standard deviations and 60-bar return correlation is above 0.60. It closes both legs when the absolute z-score falls below 0.5, rises above 4.0, or the pair has been open for 20 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | M1-MN1 | Timeframe used for pair statistics and time stop. |
| `strategy_lookback_bars` | `60` | 10-300 | Rolling window for OLS beta, spread z-score, and return correlation. |
| `strategy_entry_z` | `2.0` | 0.5-5.0 | Absolute z-score needed to open the pair trade. |
| `strategy_exit_z` | `0.5` | 0.0-2.0 | Absolute z-score below which both legs are closed as mean-reverted. |
| `strategy_hard_stop_z` | `4.0` | 2.0-10.0 | Absolute z-score above which both legs are closed as structural break. |
| `strategy_min_correlation` | `0.60` | 0.0-1.0 | Minimum rolling return correlation required before opening. |
| `strategy_time_stop_bars` | `20` | 1-120 | Maximum holding period in signal-timeframe bars. |
| `strategy_rollover_blackout_minutes` | `30` | 0-180 | Minutes before and after broker midnight to block new entries. |
| `strategy_news_blackout_minutes` | `120` | 0-360 | Minutes before and after high-impact news to block new entries. |
| `strategy_max_spread_points` | `35` | 0-500 | Maximum current chart-symbol spread allowed for entry processing. |
| `strategy_beta_min` | `0.10` | 0.0-1.0 | Reject unstable OLS beta magnitudes below this value. |
| `strategy_beta_max` | `5.00` | 1.0-20.0 | Reject unstable OLS beta magnitudes above this value. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Pair A leg A from the approved card; DWX forex matrix member.
- `GBPUSD.DWX` - Pair A leg B from the approved card; DWX forex matrix member.
- `AUDUSD.DWX` - Pair B leg A from the approved card; DWX forex matrix member.
- `NZDUSD.DWX` - Pair B leg B from the approved card; DWX forex matrix member.

**Explicitly NOT for:**
- `USDNOK.DWX` - Pair C is skipped because USDNOK is not present in `dwx_symbol_matrix.csv`.
- `USDCAD.DWX` - Pair C is incomplete without USDNOK, so USDCAD is not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `2` |
| Typical hold time | up to 20 D1 bars |
| Expected drawdown profile | bounded by z-score hard stop and fixed per-leg exposure |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7ede58dd-d184-5099-9d48-7a65de230853`
**Source type:** `paper / encyclopedia`
**Pointer:** `https://quantpedia.com` and Gatev, Goetzmann, Rouwenhorst (2006), Review of Financial Studies 19(3), 797-827
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1058_gatev-fx-pairs-zscore.md`

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
