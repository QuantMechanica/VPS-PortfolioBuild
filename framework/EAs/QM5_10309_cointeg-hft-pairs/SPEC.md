# QM5_10309_cointeg-hft-pairs - Strategy Spec

**EA ID:** QM5_10309
**Slug:** `cointeg-hft-pairs`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA evaluates fixed candidate pairs on M15 bars using a 90-trading-day formation window of log closes. It estimates an OLS hedge ratio, computes the residual z-score over the recent residual window, and requires a cointegration threshold before entering. When the residual z-score is at or above +2.0 it shorts A and buys B exposure; when the z-score is at or below -2.0 it buys A and shorts B exposure. Positions close when the residual returns to the exit z-score, the stop z-score is reached, cointegration weakens, or the max hold window expires.

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
- `EURUSD.DWX` - Registered as pair A for the EURUSD/GBPUSD FX cointegration candidate.
- `GBPUSD.DWX` - Registered as pair B for the EURUSD/GBPUSD FX cointegration candidate.
- `AUDUSD.DWX` - Registered as pair A for the AUDUSD/NZDUSD FX cointegration candidate.
- `NZDUSD.DWX` - Registered as pair B for the AUDUSD/NZDUSD FX cointegration candidate.
- `SP500.DWX` - Registered as pair A for the SP500/NDX index cointegration candidate; backtest-only per DWX discipline.
- `NDX.DWX` - Registered as pair B for the SP500/NDX index cointegration candidate.

**Explicitly NOT for:**
- `GER40.DWX` - Card candidate not registered because it is not in the current DWX matrix under that name.
- `FRA40.DWX` - Card candidate not registered because it is not in the current DWX matrix under that name.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
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
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-04 | Initial build from card | b21575ed-a640-41d6-9601-9f2add21092f |
