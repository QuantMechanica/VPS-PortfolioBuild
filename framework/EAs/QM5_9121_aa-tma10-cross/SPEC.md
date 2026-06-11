# QM5_9121_aa-tma10-cross - Strategy Spec

**EA ID:** QM5_9121
**Slug:** aa-tma10-cross
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7 (see `sources/alpha-architect-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It builds a TMA10 by applying SMA(10) to the close series three times, then opens long when the latest completed close crosses above TMA10 and opens short when it crosses below TMA10. Long positions close when the completed close is at or below TMA10, and short positions close when the completed close is at or above TMA10. New entries are skipped when the current D1 spread is more than 2.5 times the 20-day median spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tma_period` | 10 | 1-100 | Period for each of the three nested SMA passes. |
| `strategy_atr_period` | 20 | 1-200 | ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-20.0 | Initial stop distance in ATR multiples. |
| `strategy_warmup_bars` | 60 | 60-500 | Minimum completed D1 bars required before signals are allowed. |
| `strategy_spread_median_days` | 20 | 1-64 | Completed D1 bars used to calculate median spread. |
| `strategy_spread_mult` | 2.5 | 0.1-20.0 | Maximum current spread as a multiple of median spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 port from the source illustration; backtest-only custom symbol.
- `NDX.DWX` - liquid US large-cap index proxy.
- `WS30.DWX` - liquid US large-cap index proxy.
- `GDAXI.DWX` - liquid DAX index proxy.
- `XAUUSD.DWX` - liquid gold CFD for the card's multi-asset DWX port.
- `XTIUSD.DWX` - canonical DWX crude oil symbol for the card's USOIL exposure.
- `EURUSD.DWX` - liquid major FX pair.
- `GBPUSD.DWX` - liquid major FX pair.
- `USDJPY.DWX` - liquid major FX pair.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data.

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
| Trades / year / symbol | Not specified in card frontmatter |
| Typical hold time | Not specified in card frontmatter; daily trend-filter holds are expected to last days to weeks |
| Expected drawdown profile | Whipsaw drawdown during sideways regimes, bounded by ATR initial stops and TMA close exits |
| Regime preference | trend-following |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** Henry Stern, "Trend-Following Filters - Part 2/2", 2021-01-21, https://alphaarchitect.com/trend-following-filters-part-2-2/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9121_aa-tma10-cross.md`

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
| v1 | 2026-06-11 | Initial build from card | b6082e3a-b506-4ea6-8c52-684f63dfd027 |
