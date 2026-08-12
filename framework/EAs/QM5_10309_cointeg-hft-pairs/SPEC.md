# QM5_10309_cointeg-hft-pairs - Strategy Spec

**EA ID:** QM5_10309
**Slug:** `cointeg-hft-pairs`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-19

---

## 1. Strategy Logic

The EA evaluates the approved EURUSD/GBPUSD candidate as one logical M15 basket using a 90-trading-day formation window of log closes. It estimates an OLS hedge ratio, computes the residual z-score over the recent residual window, and requires a cointegration threshold before entering. When the residual z-score is at or above +2.0 it shorts EURUSD and buys beta-weighted GBPUSD exposure; when the z-score is at or below -2.0 it buys EURUSD and shorts beta-weighted GBPUSD exposure. Both legs must open or the package is rolled back. Positions close when the residual crosses zero, the stop z-score is reached, cointegration weakens, or the max hold window expires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_formation_days` | 90 | >= 1 | M15 trading days used for OLS formation and cointegration state. |
| `strategy_residual_days` | 20 | >= 1 | M15 trading days used for residual mean, residual deviation, and stop distance. |
| `strategy_coint_exit_days` | 30 | >= 1 | M15 trading days used for the exit cointegration check. |
| `strategy_coint_pvalue_max` | 0.05 | 0.0-1.0 | Maximum p-value proxy allowed for entry. |
| `strategy_coint_exit_pvalue` | 0.20 | 0.0-1.0 | Exit threshold when cointegration weakens. |
| `strategy_entry_z` | 2.0 | > 0.0 | Absolute residual z-score needed to enter. |
| `strategy_exit_z` | 0.0 | >= 0.0 | Absolute residual z-score target for mean-reversion exit. |
| `strategy_stop_z` | 3.5 | > `strategy_entry_z` | Absolute residual z-score hard stop. |
| `strategy_min_half_life_bars` | 2 | >= 1 | Minimum estimated residual half-life in M15 bars. |
| `strategy_max_half_life_bars` | 96 | >= `strategy_min_half_life_bars` | Maximum estimated residual half-life in M15 bars. |
| `strategy_max_hold_bars` | 48 | >= 1 | Maximum holding time in M15 bars. |
| `strategy_max_spread_cost_frac` | 0.15 | 0.0-1.0 | Maximum combined spread cost as a fraction of entry-to-mean distance. |
| `strategy_vol_stop_mult` | 3.5 | > 0.0 | Recent average-move multiplier used for stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `QM5_10309_EURUSD_GBPUSD_COINTEG_FX` - Logical package identity used by the farm; the manifest binds it to M15.
- `GBPUSD.DWX` - Tester host and registered package leg B (magic slot 1).
- `EURUSD.DWX` - Foreign package leg A (magic slot 0).

**Explicitly NOT for:**
- Physical single-symbol EURUSD or GBPUSD work items - they cannot evaluate the two-leg edge.
- `AUDUSD.DWX`/`NZDUSD.DWX` and `SP500.DWX`/`NDX.DWX` - approved card candidates that require separate logical sleeve manifests and evidence; they are not loaded by this sleeve.
- `GDAXI.DWX`/`FRA40.DWX` - the card candidate is unavailable under the current DWX matrix names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the GBPUSD host; both histories are read only on a new bar. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / logical package | `12` |
| Typical hold time | Up to 48 M15 bars, about 12 trading hours. |
| Expected drawdown profile | Bounded by fixed-risk package stops and residual stop exits. |
| Regime preference | Mean-revert cointegration residual regime with stable pair relationship. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** paper
**Pointer:** `https://ssrn.com/abstract=2147012`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10309_cointeg-hft-pairs.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per package, split `1:abs(beta)` across both protective stops (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-04 | Initial build from card | b21575ed-a640-41d6-9601-9f2add21092f |
| v2 | 2026-07-19 | Q03 infrastructure repair | Replaced invalid physical-symbol execution with a canonical GBP-host logical basket, true two-leg routing, weighted package risk, and partial-open rollback. |
