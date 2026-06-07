# QM5_11046_roman-stoch-rev - Strategy Spec

**EA ID:** QM5_11046
**Slug:** roman-stoch-rev
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades a fixed Stochastic reversal rule on H1. It sells when the Stochastic main line crosses above the signal line on the completed bar and the prior main value was above the top limit. It buys when the main line crosses below the signal line on the completed bar and the prior main value was below the bottom limit. Positions close on the next opposite Stochastic cross, a protective SL/TP, or a maximum holding-time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_stoch_k_period | 5 | 5-14 | Stochastic K period. |
| strategy_stoch_d_period | 3 | 3-5 | Stochastic D period. |
| strategy_stoch_slowing | 3 | 3-5 | Stochastic slowing period. |
| strategy_top_limit | 80.0 | 70-80 | Overbought threshold for short setup. |
| strategy_bottom_limit | 20.0 | 20-30 | Oversold threshold for long setup. |
| strategy_atr_period | 14 | 14 | ATR period used for the initial stop. |
| strategy_atr_sl_mult | 1.5 | 1.0-2.0 | Stop distance as ATR multiple. |
| strategy_tp_rr | 1.0 | 0.75-1.25 | Take-profit distance as R multiple. |
| strategy_max_bars_in_trade | 24 | 12-48 | Time exit in H1 bars. |
| strategy_break_even_enabled | true | true/false | Enables optional break-even management. |
| strategy_break_even_rr | 0.75 | 0.75 | Break-even trigger as R multiple. |
| strategy_break_even_buffer_pips | 0 | 0+ | Extra pips beyond entry when moving to break-even. |
| strategy_spread_median_bars | 20 | 1-128 | Rolling bar-spread sample count for spread filter. |
| strategy_spread_median_mult | 2.0 | 2.0 | Maximum current spread as multiple of median spread. |
| strategy_atr_percentile_bars | 100 | 20-256 | ATR sample count for low-volatility filter. |
| strategy_min_atr_percentile | 20.0 | 20 | Minimum ATR percentile allowed for entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed FX major used by the source framework tests and present in the DWX matrix.
- GBPUSD.DWX - Card-listed FX major used by the source framework tests and present in the DWX matrix.
- USDCHF.DWX - Card-listed FX major used by the source framework tests and present in the DWX matrix.
- USDJPY.DWX - Card-listed FX major used by the source framework tests and present in the DWX matrix.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - the approved card names the four FX pairs above for the P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 65 |
| Typical hold time | Up to 24 H1 bars unless SL, TP, break-even stop, or opposite cross exits first. |
| Expected drawdown profile | Oscillator reversals can fail in persistent trends; risk is bounded by fixed SL/TP and one active position. |
| Regime preference | Mean-reversion / oscillator-reversal. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/350
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11046_roman-stoch-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | 20bc10c7-e821-4c16-b775-5dcca2fc68e4 |
