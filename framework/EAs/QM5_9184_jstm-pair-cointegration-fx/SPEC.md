# QM5_9184_jstm-pair-cointegration-fx - Strategy Spec

**EA ID:** QM5_9184
**Slug:** jstm-pair-cointegration-fx
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `sources/github-jstm-quant-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades a deterministic Engle-Granger pair spread on `AUDUSD.DWX` and `NZDUSD.DWX`. On each closed D1 bar it estimates `OLS(NZDUSD ~ const + beta * AUDUSD)` over 250 bars, computes the residual spread z-score, and treats the pair as active only when the residual ADF t-statistic is at or below the 5% critical proxy. It opens long-spread when z-score is below -1.0 by buying AUDUSD and selling NZDUSD, and opens short-spread when z-score is above +1.0 by selling AUDUSD and buying NZDUSD. It closes both legs when absolute z-score returns below 0.25, when absolute z-score exceeds 3.0, when the ADF t-statistic breaks above the critical proxy, or after 60 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | D1 intended | Timeframe used for OLS, residual, z-score, and ADF calculations. |
| `strategy_lookback_bars` | `250` | `30+` | Rolling Engle-Granger and z-score window. |
| `strategy_entry_z` | `1.0` | `>0` | Absolute z-score threshold for pair entry. |
| `strategy_exit_abs_z` | `0.25` | `0-entry_z` | Absolute z-score threshold for mean-reversion exit. |
| `strategy_stop_abs_z` | `3.0` | `>entry_z` | Hard z-score stop threshold. |
| `strategy_adf_t_critical` | `-2.86` | negative | Deterministic ADF 5% critical t-stat proxy. |
| `strategy_time_stop_bars` | `60` | `1+` | Maximum holding period in signal bars. |
| `strategy_sizing_pips` | `200` | `1+` | Nominal per-leg sizing distance used only to convert fixed/percent risk into lots. |
| `strategy_max_spread_points` | `50` | `0+` | Host-symbol maximum spread guard; zero spread is allowed. |
| `strategy_max_spread_cost_fraction` | `0.50` | `0+` | Entry cost cap as a fraction of expected residual reversion distance. |
| `strategy_beta_min` | `0.10` | `>0` | Minimum absolute hedge ratio accepted. |
| `strategy_beta_max` | `5.00` | `>beta_min` | Maximum absolute hedge ratio accepted. |
| `strategy_deviation_points` | `20` | `1+` | Basket order slippage/deviation allowance. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - AUD leg of the selected commodity-currency FX pair from the approved candidate list.
- `NZDUSD.DWX` - NZD leg of the selected commodity-currency FX pair from the approved candidate list.

**Explicitly NOT for:**
- `USDMXN.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`.
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX` - listed as cross-asset candidates, but this build is the FX pair variant and registers one selected pair.

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
| Typical hold time | `days to 60 D1 bars` |
| Expected drawdown profile | Mean-reversion drawdowns during residual divergence, bounded by cointegration break, z-stop, and time stop. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** `je-suis-tm/quant-trading`, file `Pair trading backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9184_jstm-pair-cointegration-fx.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Current Funnel State

The 2026-07-09 forex fallback pass found no unbuilt, card-worthy FX
cointegration pair left in the documented strict or extended scan frontier. The
anchors `QM5_12532` and `QM5_12533` are not Q02-blocked, and the extended
siblings already reached later terminal gates.

`QM5_9184` remains an existing AUDUSD/NZDUSD D1 FX cointegration fallback with
a pending AUDUSD-host Q02 retry:

- Pending Q02 work item: `3bb02373-5f50-496e-9558-8590a25837db`.
- Prior AUDUSD Q02 attempts stopped on `NO_HISTORY` / `INCOMPLETE_RUNS`.
- Prior NZDUSD Q02 attempts reached a strategy `MIN_TRADES_NOT_MET` verdict.
- Added `basket_manifest.json` so the worker warms both `AUDUSD.DWX` and
  `NZDUSD.DWX` for the pending AUDUSD retry.
- Updated the existing pending Q02 payload in place with `portfolio_scope=basket`
  and the manifest path; no duplicate work item was inserted.

Validation after the manifest repair:

- `validate_symbol_scope.py --ea-label QM5_9184_jstm-pair-cointegration-fx --verbose`: `BASKET_OK`, 0 violations.
- `build_check.ps1 -EALabel QM5_9184_jstm-pair-cointegration-fx -SkipCompile`: `PASS`, 0 failures, 0 warnings.

No manual MT5 run was launched; the paced worker owns the pending Q02 row under
the CPU-ceiling discipline.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-26 | Initial build from card | 7fd5a807-876a-4d6e-8cf8-68c9b2bfa43f |
| v2 | 2026-07-09 | FX Q02 basket-manifest repair | Added `basket_manifest.json`, validated basket scope/build check, and priority-marked the existing pending AUDUSD Q02 retry without inserting a duplicate work item. |
