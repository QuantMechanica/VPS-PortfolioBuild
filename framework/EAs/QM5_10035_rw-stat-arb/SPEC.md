# QM5_10035_rw-stat-arb - Strategy Spec

**EA ID:** QM5_10035
**Slug:** rw-stat-arb
**Source:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

On each D1 close, the EA computes a 5-day log return for the five registered index CFD proxies, subtracts the basket mean, and divides by the basket standard deviation to produce a cross-sectional z-score. It opens a long on one of the two lowest-ranked symbols when its z-score is at or below -0.75, and opens a short on one of the two highest-ranked symbols when its z-score is at or above +0.75. It skips new entries unless at least four basket symbols are eligible and the current basket dispersion is at least 25% of the median 60-day dispersion. It exits when the z-score mean-reverts past the exit threshold, when the position reaches a 5-trading-day time stop, or when the synthetic per-symbol portfolio stop reaches 1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_return_lookback_days` | 5 | 3-10 | D1 log-return lookback used to rank the basket. |
| `strategy_entry_z` | 0.75 | 0.50-1.00 | Absolute z-score threshold for new long or short entries. |
| `strategy_exit_z` | 0.10 | 0.00-0.25 | Mean-reversion threshold for strategy exits. |
| `strategy_atr_period` | 20 | 10-60 | ATR period used for the per-symbol stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-5.0 | ATR multiple for initial stop loss distance. |
| `strategy_hold_days` | 5 | 3-10 | Maximum holding period in D1 bars. |
| `strategy_dispersion_lookback_days` | 60 | 20-120 | Lookback used to estimate median cross-sectional dispersion. |
| `strategy_min_dispersion_fraction` | 0.25 | 0.00-1.00 | Minimum current dispersion as a fraction of the 60-day median. |
| `strategy_min_eligible_symbols` | 4 | 4-5 | Minimum number of fresh basket symbols required. |
| `strategy_max_spread_points` | 250 | 0-1000 | Maximum current spread in points; 0 disables the spread gate. |
| `strategy_portfolio_stop_r` | 1.5 | 0.5-5.0 | Synthetic stop threshold in units of the active risk budget. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol proxy for the US large-cap leg; backtest-only per DWX discipline.
- `NDX.DWX` - Nasdaq 100 proxy for US large-cap technology/growth exposure.
- `WS30.DWX` - Dow 30 proxy for US large-cap value/industrial exposure.
- `GDAXI.DWX` - available DWX DAX proxy used in place of card-stated `GER40.DWX`, which is not in the current matrix.
- `UK100.DWX` - FTSE 100 proxy for the UK large-cap index leg.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated DAX name, but absent from `framework/registry/dwx_symbol_matrix.csv`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; the canonical custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | 1-5 trading days |
| Expected drawdown profile | Basket mean-reversion sleeve with losses capped by 2.0 ATR per-symbol stops and a 1.5R synthetic stop. |
| Regime preference | cross-sectional mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Source type:** blog / newsletter
**Pointer:** Robot Wealth, "Index of Strategies" Equity Stat Arb section, https://robotwealth.com/index-of-strategies/; Kris Longmore, "RW Pro Newsletter: From Signal to Portfolio: Towards A Practical Guide to Implementing Stat Arb", https://robotwealth.com/rw-pro-newsletter-from-signal-to-portfolio-towards-a-practical-guide-to-implementing-stat-arb/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10035_rw-stat-arb.md`

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
| v1 | 2026-06-09 | Initial build from card | 2d9aea85-5d6e-4e66-819a-b42a4c8d2947 |
