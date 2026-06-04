# QM5_10309_cointeg-hft-pairs - Strategy Spec

**EA ID:** QM5_10309
**Slug:** `cointeg-hft-pairs`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA trades fixed M15 cointegration pairs. It estimates an OLS hedge ratio between two log-price series, builds the residual spread, and enters when the residual z-score is at least 2.0 standard deviations away from its mean while the rolling cointegration check remains valid. A positive z-score shorts leg A and buys leg B; a negative z-score buys leg A and shorts leg B. The package exits when the residual returns to zero, cointegration deteriorates, the z-score reaches the stop threshold, or the maximum holding window expires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_formation_days` | 90 | 20-252 | M15 trading-day window for OLS hedge-ratio estimation. |
| `strategy_residual_days` | 20 | 5-90 | M15 trading-day window used for residual mean and standard deviation. |
| `strategy_coint_exit_days` | 30 | 5-120 | Rolling window used to detect deteriorating cointegration before exit. |
| `strategy_coint_pvalue_max` | 0.05 | 0.01-0.20 | Maximum cointegration p-value proxy allowed for entry. |
| `strategy_coint_exit_pvalue` | 0.20 | 0.05-0.50 | Cointegration p-value proxy above which the package exits. |
| `strategy_entry_z` | 2.0 | 0.5-5.0 | Absolute residual z-score threshold for entry. |
| `strategy_exit_z` | 0.0 | 0.0-1.0 | Absolute residual z-score threshold for mean-reversion exit. |
| `strategy_stop_z` | 3.5 | 1.0-8.0 | Absolute residual z-score stop threshold. |
| `strategy_min_half_life_bars` | 2 | 1-48 | Minimum accepted residual half-life in M15 bars. |
| `strategy_max_half_life_bars` | 96 | 12-384 | Maximum accepted residual half-life in M15 bars. |
| `strategy_max_hold_bars` | 48 | 4-384 | Maximum package hold duration in M15 bars. |
| `strategy_max_spread_cost_frac` | 0.15 | 0.01-0.50 | Maximum combined spread cost as a fraction of entry-to-mean distance. |
| `strategy_vol_stop_mult` | 3.5 | 0.5-10.0 | Volatility multiplier used to place the per-leg protective stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - first leg of the liquid EURUSD/GBPUSD FX pair.
- `GBPUSD.DWX` - second leg of the liquid EURUSD/GBPUSD FX pair.
- `AUDUSD.DWX` - first leg of the liquid AUDUSD/NZDUSD FX pair.
- `NZDUSD.DWX` - second leg of the liquid AUDUSD/NZDUSD FX pair.
- `SP500.DWX` - first leg of the US large-cap index pair, valid for backtest-only S&P 500 exposure.
- `NDX.DWX` - second leg of the US large-cap index pair and live-routable Nasdaq 100 exposure.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - unavailable symbols cannot be registered or backtested under DWX discipline.
- Single unpaired symbols - the strategy requires a fixed two-leg cointegration package.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | up to 48 M15 bars |
| Expected drawdown profile | bounded package mean-reversion losses with fixed $1,000 P2 risk convention |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** `paper`
**Pointer:** SSRN abstract page for "Statistical Arbitrage Trading Strategies and High Frequency Trading", Thomas A. Hanson and Joshua Hall, 2012/2013.
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
