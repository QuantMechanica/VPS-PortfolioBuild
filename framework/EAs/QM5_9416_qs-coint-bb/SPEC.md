# QM5_9416_qs-coint-bb - Strategy Spec

**EA ID:** QM5_9416
**Slug:** `qs-coint-bb`
**Source:** `842161b9-a728-55c7-97e8-33e33719b70c` (QuantStart article card)
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

This EA trades deterministic daily pairs mean reversion from the QuantStart cointegrated spread Bollinger concept. For each configured pair it uses completed D1 closes, estimates `log(y) = alpha + beta * log(x)` with OLS over 252 bars, and accepts the pair only when a residual CADF-style regression has a negative residual slope with t-statistic at or below the configured threshold.

The daily spread is `spread_t = log(y_t) - (alpha + beta * log(x_t))`. The EA calculates the 15-bar spread mean and standard deviation, then enters long spread when `z < -1.5` by buying the y-leg and selling the beta-adjusted x-leg. It enters short spread when `z > +1.5` by selling the y-leg and buying the beta-adjusted x-leg. Long spread exits when `z >= -0.5`; short spread exits when `z <= +0.5`. Both legs also close if `abs(z) >= 4.0`, the monthly model fails the CADF gate, beta leaves `0.25..4.0`, Friday close triggers, or either leg is unavailable.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_D1` | D1 only | Timeframe used for pair closes and new-bar gating. |
| `strategy_warmup_bars` | 252 | 32-1000 | Minimum completed D1 bars required before trading. |
| `strategy_ols_lookback_bars` | 252 | 32-1000 | Bars used for monthly OLS hedge-ratio estimation. |
| `strategy_spread_lookback_bars` | 15 | 5-100 | Bars used for spread Bollinger mean and standard deviation. |
| `strategy_entry_z` | 1.5 | 0.5-4.0 | Absolute z-score threshold for pair entry. |
| `strategy_exit_z` | 0.5 | 0.0-2.0 | Mean-reversion z-score threshold for pair exit. |
| `strategy_stop_z` | 4.0 | 2.0-8.0 | Pair-level protective spread stop. |
| `strategy_cadf_t_threshold` | -2.0 | -5.0--0.5 | Maximum residual ADF t-statistic allowed for the monthly gate. |
| `strategy_beta_min` | 0.25 | 0.01-4.0 | Lower allowed hedge beta. |
| `strategy_beta_max` | 4.0 | 0.25-10.0 | Upper allowed hedge beta. |
| `strategy_sizing_pips` | 200 | 20-1000 | Synthetic stop distance used by fixed-risk lot sizing for each leg. |
| `strategy_max_spread_points` | 80 | 0-1000 | Maximum allowed current bid/ask spread per leg; 0 disables the cap. |
| `strategy_deviation_points` | 20 | 1-200 | Trade deviation passed to basket orders. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` / `NDX.DWX` - related US equity index pair from the approved card; SP500 has the card's live-routing caveat.
- `WS30.DWX` / `NDX.DWX` - related US equity index pair with a non-SP500 y-leg for diversity and parallel validation.

**Explicitly NOT for:**
- Single-leg symbols - the signal requires two correlated instruments and basket execution.
- Non-DWX symbols - Q02 setfiles and magic rows are reserved only for `.DWX` symbols.
- `NDX.DWX` as host - it is the shared x-leg and is not used as a chart host for Q02.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` on D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 80 per approved card before gate attrition |
| Typical hold time | Days to weeks |
| Expected drawdown profile | Mean-reversion drawdowns cluster during index leadership breaks and volatility shocks |
| Regime preference | Cointegrated pair mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Source type:** article
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9416_qs-coint-bb.md`
**R1-R4 verdict (Q00):** all PASS in the approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade pair, split across two hedge-adjusted legs |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%-0.5% |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v2 | 2026-06-28 | Q02 queue repair | Added basket manifest for the framework-review exception and pinned all strategy/news inputs in queued RISK_FIXED setfiles. |
| v1 | 2026-06-27 | Initial build from approved card | pending build commit |
