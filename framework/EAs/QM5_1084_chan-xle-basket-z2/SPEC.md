# QM5_1084_chan-xle-basket-z2 - Strategy Spec

**EA ID:** QM5_1084
**Slug:** chan-xle-basket-z2
**Source:** fce67611-4e0f-5dce-8cff-c8b9dd84dd49 (see `strategy-seeds/sources/fce67611-4e0f-5dce-8cff-c8b9dd84dd49/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a fixed daily spread: `SP500.DWX - ndx_weight * NDX.DWX - ws30_weight * WS30.DWX - gdaxi_weight * GDAXI.DWX`. It normalizes that spread to a z-score over a fixed D1 lookback. When z-score is at or below -2, it buys the SP500 leg and sells the hedge legs; when z-score is at or above +2, it sells the SP500 leg and buys the hedge legs. It closes the basket when z-score crosses zero, when absolute z-score reaches 4, or when the basket has been held for `3 * strategy_half_life_bars`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_lookback_d1 | 100 | 20-500 | D1 spread window used for mean and standard deviation. |
| strategy_entry_z | 2.0 | 0.5-5.0 | Absolute z-score needed to open the basket. |
| strategy_exit_z | 0.0 | 0.0-2.0 | Exit band; zero means require a true zero-cross. |
| strategy_stop_z | 4.0 | 2.0-8.0 | Hard z-score stop for failed convergence. |
| strategy_half_life_bars | 20 | 1-120 | Fixed spread half-life in D1 bars for max-hold timeout. |
| strategy_atr_period_d1 | 20 | 2-100 | D1 ATR period used for per-leg protective stops. |
| strategy_atr_sl_mult | 4.0 | 0.5-10.0 | ATR multiple for per-leg protective stops. |
| strategy_max_spread_points | 250 | 0-10000 | Maximum broker spread per leg; 0 disables this filter. |
| strategy_ndx_weight | 0.3333333333 | 0.0-2.0 | Fixed hedge coefficient for NDX.DWX. |
| strategy_ws30_weight | 0.3333333333 | 0.0-2.0 | Fixed hedge coefficient for WS30.DWX. |
| strategy_gdaxi_weight | 0.3333333333 | 0.0-2.0 | Fixed hedge coefficient for GDAXI.DWX. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - target leg for the ported US large-cap sector/index spread.
- NDX.DWX - liquid US large-cap technology/growth hedge leg available in DWX.
- WS30.DWX - liquid US large-cap value/industrial hedge leg available in DWX.
- GDAXI.DWX - DAX hedge leg; card mentions GER40.DWX, but the mounted DWX matrix exposes GDAXI.DWX as the available DAX symbol.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv` in this workspace.
- SPY.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; SP500.DWX is the canonical S&P 500 custom symbol.
- XLE.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; the card's R3 port maps sector ETF exposure to available index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Up to `3 * strategy_half_life_bars` D1 bars; default maximum is 60 D1 bars. |
| Expected drawdown profile | Mean-reversion basket drawdowns can cluster when the spread trends before converging. |
| Regime preference | Statistical-arbitrage mean reversion. |
| Win rate target (qualitative) | Medium to high, conditional on stable spread behaviour. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fce67611-4e0f-5dce-8cff-c8b9dd84dd49
**Source type:** blog
**Pointer:** Ernest P. Chan, "A not-so-simple way to trade a gold-miners-gold pair", 2007-03-15, and supplement dated 2006-11-24
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1084_chan-xle-basket-z2.md`

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
| v1 | 2026-06-14 | Initial build from card | f553dfad-08ca-475a-ae71-bdf500fe4b38 |
