# QM5_12507_pair-coint-z - Strategy Spec

**EA ID:** QM5_12507
**Slug:** `pair-coint-z`
**Source:** `46758070-d6b1-52ef-a3ee-ffcbffb7bb54` (see `strategy-seeds/sources/46758070-d6b1-52ef-a3ee-ffcbffb7bb54/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades two fixed pairs on completed H1 bars: EURUSD versus GBPUSD, and NDX versus WS30. For the active chart symbol's pair it regresses asset2 close on asset1 close over the rolling bandwidth window, computes the residual, requires the residual to pass the ADF critical threshold and have a negative error-correction coefficient, then converts the latest residual to a z-score. If z is above the entry threshold it buys asset1 and sells asset2; if z is below the negative threshold it sells asset1 and buys asset2. It closes both legs when cointegration fails, z reverts inside the zero band, the opposite threshold fires, the residual moves adversely by the emergency stop distance, or the maximum hold time is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `bandwidth_bars` | 250 | 150-350 | Rolling H1 bars used for the regression, ADF check, residual mean, and residual standard deviation. |
| `adf_pvalue_max` | 0.05 | 0.01-0.05 | Maximum ADF p-value threshold, implemented as the deterministic 1%/5% critical value mapping used by local V5 cointegration EAs. |
| `z_entry` | 1.0 | 1.0-2.0 | Absolute residual z-score threshold for opening a pair trade. |
| `z_exit` | 0.25 | 0.0-0.5 | Absolute residual z-score band for closing a mean-reverted pair. |
| `max_holding_bars` | 20 | 10-40 | Maximum H1 bars to hold an open pair before time-stop close. |
| `residual_stop_mult` | 2.0 | fixed | Pair-level emergency stop distance in rolling residual standard deviations. |
| `strategy_max_spread_points` | 0 | 0+ | Optional pair-leg spread cap; 0 leaves only framework spread controls active. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - first leg of the approved FX cointegration pair.
- `GBPUSD.DWX` - second leg of the approved FX cointegration pair.
- `NDX.DWX` - first leg of the approved US index cointegration pair.
- `WS30.DWX` - second leg of the approved US index cointegration pair.

**Explicitly NOT for:**
- Any symbol outside `dwx_symbol_matrix.csv` - the card declares only the fixed four-symbol pair basket.

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
| Trades / year / symbol | `20` |
| Typical hold time | Up to 20 H1 bars |
| Expected drawdown profile | High risk from cointegration breaks with pair-level residual stop. |
| Regime preference | Mean-revert / cointegration |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `46758070-d6b1-52ef-a3ee-ffcbffb7bb54`
**Source type:** `GitHub script`
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/Pair%20trading%20backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12507_pair-coint-z.md`

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
| v1 | 2026-06-11 | Initial build from card | 34b946aa-e1c9-4f38-b713-ee3a8efbb8e3 |
