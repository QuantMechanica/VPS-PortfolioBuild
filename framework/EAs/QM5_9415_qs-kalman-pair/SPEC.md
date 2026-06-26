# QM5_9415_qs-kalman-pair - Strategy Spec

**EA ID:** QM5_9415
**Slug:** qs-kalman-pair
**Source:** 842161b9-a728-55c7-97e8-33e33719b70c (see `strategy-seeds/sources/842161b9-a728-55c7-97e8-33e33719b70c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades a two-leg spread using a deterministic Kalman filter estimate of intercept and hedge ratio. On each D1 close it reads the paired log closes, updates the filter, computes forecast error `e = y - (alpha + beta * x)`, and opens a long spread when `e` is below `-1.0 * forecast_std` or a short spread when `e` is above `+1.0 * forecast_std`. Long spread means buy the y-leg and sell the x-leg; short spread means sell the y-leg and buy the x-leg. It exits both legs when the forecast error reverts back inside the entry threshold, when `abs(e / forecast_std) >= 3.0`, or when Friday flat policy is active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | D1 expected | Timeframe used for paired closes and signal cadence. |
| `strategy_warmup_bars` | `60` | `60+` | Minimum paired daily bars before trading. |
| `strategy_kalman_history_bars` | `180` | `60+` | Number of closed paired bars used to reconstruct the Kalman state. |
| `strategy_kalman_delta` | `0.0001` | `0.00000001-0.999` | Fixed Kalman process-noise scalar. |
| `strategy_kalman_obs_variance` | `0.0010` | `>0` | Fixed observation variance used in forecast variance. |
| `strategy_entry_z` | `1.0` | `>0` | Entry and zero-cross exit threshold in forecast standard deviations. |
| `strategy_stop_z` | `3.0` | `>strategy_entry_z` | Pair-level forecast-error stop threshold. |
| `strategy_beta_min` | `0.25` | `>0` | Lower allowed hedge-ratio bound. |
| `strategy_beta_max` | `4.00` | `>=strategy_beta_min` | Upper allowed hedge-ratio bound. |
| `strategy_sizing_pips` | `200` | `>0` | Synthetic stop distance used by framework risk sizing. |
| `strategy_max_spread_points` | `80` | `0+` | Maximum positive modeled spread per leg; zero spread is allowed. |
| `strategy_deviation_points` | `20` | `0+` | Broker deviation points for basket orders. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented
> here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - y-leg for the card's S&P 500 backtest proxy pair.
- `NDX.DWX` - alternate y-leg named by the card for a live-routable US index proxy.
- `XAUUSD.DWX` - x-leg proxy paired against the selected index y-leg.

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX symbol matrix.
- `SPY.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

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
| Trades / year / symbol | `100` |
| Typical hold time | `days` |
| Expected drawdown profile | `Pair-level fixed-risk with 3.0 forecast-standard-deviation stop` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 842161b9-a728-55c7-97e8-33e33719b70c
**Source type:** article
**Pointer:** https://www.quantstart.com/articles/kalman-filter-based-pairs-trading-strategy-in-qstrader/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9415_qs-kalman-pair.md`

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
| v1 | 2026-06-26 | Initial build from card | 0882fb78-c10b-4132-a13b-4e95a99d9873 |
