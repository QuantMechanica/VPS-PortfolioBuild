# QM5_12395_country-pairs - Strategy Spec

**EA ID:** QM5_12395
**Slug:** country-pairs
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades daily country-index pairs. Every 20 D1 bars it uses the prior 120 closed D1 bars to normalize each eligible index by its oldest formation close, computes pair distance as the sum of squared normalized-spread differences, and selects the closest non-overlapping pairs. During the trading period it opens a market-neutral pair when the normalized spread moves more than 0.5 standard deviations away from its formation mean: the rich leg is sold and the cheap leg is bought. The pair is closed when the spread returns inside mean plus or minus 0.5 standard deviations, when it reaches the 2.5 standard deviation pair stop, or when the 20-bar trading period ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_formation_bars | 120 | 60-180 | D1 bars used to form normalized pair distances and spread statistics. |
| strategy_trading_period_bars | 20 | 10-30 | D1 bars before forced time-stop and pair recomputation. |
| strategy_entry_stdev | 0.5 | 0.5-1.5 | Entry threshold in formation spread standard deviations. |
| strategy_stop_stdev | 2.5 | > strategy_entry_stdev | Pair-level stop threshold in formation spread standard deviations. |
| strategy_max_active_pairs | 3 | 1-3 | Maximum selected non-overlapping active pairs in the DWX port. |
| strategy_stale_days | 3 | 1-10 | Maximum allowed calendar age for either leg's D1 data. |
| strategy_max_spread_points | 0 | 0+ | Optional wide-spread block; zero disables the cap and does not fail on DWX zero spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 proxy named by the approved card and present in the DWX matrix for backtest.
- NDX.DWX - Nasdaq 100 country/index proxy named by the approved card and present in the DWX matrix.
- WS30.DWX - Dow 30 country/index proxy named by the approved card and present in the DWX matrix.
- GDAXI.DWX - DAX country/index proxy named by the approved card and present in the DWX matrix.
- UK100.DWX - FTSE 100 country/index proxy named by the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- JPN225.DWX - named by the card but absent from `framework/registry/dwx_symbol_matrix.csv` at build time.
- JP225.DWX - Nikkei fallback mentioned by porting rules only if present; absent from the DWX matrix at build time.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Up to 20 trading days |
| Expected drawdown profile | Mean-reversion pair drawdowns cluster when index relationships trend apart. |
| Regime preference | mean-revert / statistical-arbitrage |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public GitHub implementation / Quantpedia-style strategy implementation
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/pairs-trading-with-country-etfs.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12395_country-pairs.md`

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
| v1 | 2026-06-18 | Initial build from card | e6e4b918-439c-4a6f-9015-c8377d74d3e0 |
