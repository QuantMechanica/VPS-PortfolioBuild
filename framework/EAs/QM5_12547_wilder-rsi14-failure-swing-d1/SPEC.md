# QM5_12547_wilder-rsi14-failure-swing-d1 - Strategy Spec

**EA ID:** QM5_12547
**Slug:** wilder-rsi14-failure-swing-d1
**Source:** wilder-new-concepts-1978-ch4
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades Wilder's RSI(14) failure swing on D1 closes. A long setup starts when RSI falls below 30, then rebounds above 30, pulls back while holding above 30, and finally breaks above the rebound high; the EA buys on the next bar with the stop at the lowest price in the setup window. Shorts mirror the same structure above 70, with the stop at the highest price in the setup window. Profit target is fixed at 2.0 times the entry-to-stop risk, and positions close early only when RSI crosses 50 adversely after at least five D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | 2+ | RSI lookback period on D1 closes. |
| strategy_rsi_oversold | 30.0 | 0-50 | Long setup threshold. |
| strategy_rsi_overbought | 70.0 | 50-100 | Short setup threshold. |
| strategy_rsi_midline | 50.0 | oversold-overbought | Adverse time-stop cross level. |
| strategy_tp_rr | 2.0 | >0 | Profit target as a multiple of initial risk. |
| strategy_time_stop_bars | 5 | 0+ | Minimum D1 bars before the adverse RSI midline exit can close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX FX pair with D1 RSI history.
- GBPUSD.DWX - card-listed DWX FX pair with D1 RSI history.
- USDJPY.DWX - card-listed DWX FX pair with D1 RSI history.
- AUDUSD.DWX - card-listed DWX FX pair with D1 RSI history.
- USDCAD.DWX - card-listed DWX FX pair with D1 RSI history.
- XAUUSD.DWX - card-listed DWX gold symbol with D1 RSI history.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to the DWX backtest harness.

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
| Trades / year / symbol | 10 |
| Typical hold time | several days |
| Expected drawdown profile | About 18% expected drawdown per card frontmatter. |
| Regime preference | Mean-reversion reversal after oversold or overbought RSI structure confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** wilder-new-concepts-1978-ch4
**Source type:** book
**Pointer:** `C:/Users/Administrator/Downloads/53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf`, Ch.4 pp. 63-70
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12547_wilder-rsi14-failure-swing-d1.md`

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
| v1 | 2026-06-13 | Initial build from card | c71a0eda-8bc3-45f7-a566-9099256c7f11 |
