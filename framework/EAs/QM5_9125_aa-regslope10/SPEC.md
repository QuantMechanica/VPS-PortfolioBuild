# QM5_9125_aa-regslope10 - Strategy Spec

**EA ID:** QM5_9125
**Slug:** `aa-regslope10`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates the final completed D1 bar. It fits a 10-bar ordinary least squares regression over daily closes using `t = -9..0` and trades the slope coefficient. It opens long when the current slope is above zero and the previous slope was at or below zero, opens short when the current slope is below zero and the previous slope was at or above zero, and exits when the slope crosses back through zero against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_regression_period` | 10 | 2-64 | Number of completed D1 closes used in the OLS slope window. |
| `strategy_min_d1_bars` | 30 | >= regression period + 1 | Minimum completed D1 history required before signals are valid. |
| `strategy_atr_period` | 20 | >= 1 | D1 ATR period for the initial stop loss. |
| `strategy_atr_sl_mult` | 2.5 | > 0 | Initial stop distance as ATR multiple. |
| `strategy_spread_lookback` | 20 | >= 0 | D1 spread sample count for the median-spread entry filter; 0 disables it. |
| `strategy_spread_median_mult` | 2.5 | > 0 | Blocks new entries when latest completed D1 spread is above this multiple of median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 daily trend proxy from the source illustration; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 daily index CFD proxy for US large-cap trend exposure.
- `WS30.DWX` - Dow 30 daily index CFD proxy for US large-cap trend exposure.
- `GDAXI.DWX` - DAX daily index CFD proxy for European index trend exposure.
- `XAUUSD.DWX` - Gold daily CFD proxy for commodity trend exposure.
- `XTIUSD.DWX` - WTI crude daily CFD proxy; used as the matrix-available port for card-stated USOIL.
- `EURUSD.DWX` - Major FX daily trend proxy.
- `GBPUSD.DWX` - Major FX daily trend proxy.
- `USDJPY.DWX` - Major FX daily trend proxy.

**Explicitly NOT for:**
- `USOIL.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `XTIUSD.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; canonical available name is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Days, until opposite D1 regression-slope zero-cross |
| Expected drawdown profile | Trend-following losses cluster during sideways regimes and slope whipsaws. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog
**Pointer:** Henry Stern, "Trend-Following Filters - Part 8", 2024-09-17, `https://alphaarchitect.com/trend-following-filters-part-8/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9125_aa-regslope10.md`

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
| v1 | 2026-05-25 | Initial build from card | 7986373b-aa6f-4813-a714-88b671056d85 |
