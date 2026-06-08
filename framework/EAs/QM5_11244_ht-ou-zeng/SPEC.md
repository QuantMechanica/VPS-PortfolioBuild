# QM5_11244_ht-ou-zeng - Strategy Spec

**EA ID:** QM5_11244
**Slug:** `ht-ou-zeng`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA estimates a daily Ornstein-Uhlenbeck model from a fixed formation window of log closes for the chart symbol. It converts the latest price into a dimensionless OU z-score, sells when the score is at or above the entry threshold, and buys when the score is at or below the negative entry threshold. Positions close when the z-score reverts to the close threshold, when the z-score reaches the outer stop threshold, or when the max D1 holding period elapses. The implementation uses the card's single-symbol log-deviation fallback because the standard V5 market-order hook opens the chart symbol rather than a two-leg spread basket.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_formation_bars` | 252 | 126-504 | D1 closed bars used for the OU formation estimate. |
| `strategy_optimize_objective` | `expected_return` | `expected_return`, `sharpe_ratio` | Label for the card's fixed threshold objective; P3 can sweep this value. |
| `strategy_entry_threshold_floor` | 1.0 | 0.75-1.25 | Minimum absolute z-score required for entry. |
| `strategy_close_threshold` | 0.25 | 0.0-0.5 | Mean-reversion z-score used for discretionary exit and TP placement. |
| `strategy_max_hold_bars` | 60 | 30-90 | Maximum D1 bars to hold one OU cycle. |
| `strategy_stop_extra_z` | 1.5 | fixed baseline | Extra z-score distance added to the entry threshold for the stop. |
| `strategy_max_spread_points` | 0 | 0 or broker-specific cap | Optional spread hard cap; zero disables the cap while the OU cost guard remains active. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - part of the card's EURUSD/GBPUSD portable FX spread pair and valid as a single-symbol log-deviation fallback.
- `GBPUSD.DWX` - part of the card's EURUSD/GBPUSD portable FX spread pair and valid as a single-symbol log-deviation fallback.
- `AUDUSD.DWX` - part of the card's AUDUSD/NZDUSD portable FX spread pair and valid as a single-symbol log-deviation fallback.
- `NZDUSD.DWX` - part of the card's AUDUSD/NZDUSD portable FX spread pair and valid as a single-symbol log-deviation fallback.
- `XAUUSD.DWX` - card-listed metals target, tested as a single-symbol mean-reverting log-deviation process.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/test harness has no approved DWX data for them.
- Non-D1 deployments - the OU formation, hold cap, and card period are defined on daily closes.

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
| Trades / year / symbol | 28 |
| Typical hold time | Up to 60 D1 bars per OU cycle |
| Expected drawdown profile | Mean-reversion losses occur when deviations continue away from the OU mean before reverting. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** `research notebook / paper`
**Pointer:** Hudson & Thames OU Model Optimal Trading Thresholds Zeng notebook, https://github.com/hudson-and-thames/arbitrage_research/blob/master/Time%20Series%20Approach/ou_model_optimal_threshold_Zeng.ipynb
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11244_ht-ou-zeng.md`

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
| v1 | 2026-06-08 | Initial build from card | 20b51ec4-8f31-4dc1-83cd-9f9b25352a05 |
