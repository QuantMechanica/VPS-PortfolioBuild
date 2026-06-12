# QM5_10327_eod-reversal - Strategy Spec

**EA ID:** QM5_10327
**Slug:** eod-reversal
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades the final U.S. cash-session M30 reversal proxy. At the configured final-half-hour start, it ranks the registered index CFD basket by rest-of-day return from the prior cash close to one hour before the current cash close. It buys the weakest current chart symbol when that return is below the basket median by at least 0.50 x ATR(14,M30) / price, shorts the strongest current chart symbol on the symmetric condition, uses a 0.50 x ATR(14,M30) stop, and exits at the configured cash close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_hhmm_broker | 2230 | 0000-2359 | Broker-time start of the final U.S. cash-session M30 bar. |
| strategy_cash_close_hhmm_broker | 2300 | 0000-2359 | Broker-time cash close used for the no-overnight exit. |
| strategy_rank_cutoff_hhmm_broker | 2130 | 0000-2359 | Broker-time M30 bar whose close proxies one hour before cash close. |
| strategy_prior_close_hhmm_broker | 2230 | 0000-2359 | Broker-time prior-session close bar used as the return start point. |
| strategy_atr_period | 14 | 1-200 | ATR period for signal threshold and stop distance. |
| strategy_signal_atr_mult | 0.50 | 0.01-5.00 | Required distance from basket median in ATR-normalized return terms. |
| strategy_stop_atr_mult | 0.50 | 0.01-5.00 | Stop-loss distance in ATR multiples. |
| strategy_lookback_bars | 240 | 60-2000 | M30 history scanned for today's cutoff and prior cash close bars. |
| strategy_spread_lookback_bars | 960 | 0-5000 | M30 history scanned for final-half-hour spread percentile. |
| strategy_spread_percentile | 80.0 | 1-99 | Spread percentile above which the final-half-hour signal is skipped. |
| strategy_min_valid_symbols | 3 | 3-4 | Minimum basket symbols with valid M30 data required for ranking. |
| strategy_skip_us_early_closes | true | true/false | Skips common U.S. early-close dates. |
| strategy_skip_news_days | true | true/false | Uses the central news calendar to skip high-impact news days. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only strategy-specific inputs are listed.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol named in the approved R3 basket; backtest-only T6 caveat remains outside build scope.
- `NDX.DWX` - Nasdaq 100 index CFD named in the approved R3 basket.
- `WS30.DWX` - Dow 30 index CFD named in the approved R3 basket.
- `GDAXI.DWX` - available DAX custom symbol used as the DWX matrix port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated DAX name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DWX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX symbols for the S&P 500 basket.
- FX, metals, and energy symbols - they do not share the same U.S. equity-index close-window reversal structure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Final half-hour, approximately 30 minutes |
| Expected drawdown profile | Short intraday exposure with ATR-bounded stop losses and no overnight carry. |
| Regime preference | Mean-revert / cross-sectional end-of-day reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5039009
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10327_eod-reversal.md`

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
| v1 | 2026-06-12 | Initial build from card | e0778b02-ea8e-4064-842e-04563a4dbc69 |
