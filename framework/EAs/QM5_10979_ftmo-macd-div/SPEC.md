# QM5_10979_ftmo-macd-div - Strategy Spec

**EA ID:** QM5_10979
**Slug:** ftmo-macd-div
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 MACD swing divergence reversals. A long setup requires a confirmed 3-left / 3-right swing low that is lower than the prior confirmed swing low, while the MACD(12,26,9) line at the newer low is higher than at the prior low. A short setup mirrors this with a higher swing high and lower MACD line. Entry is at market after the MACD line crosses the signal line; exits are the configured SL/TP, an opposite MACD signal-line cross, or a 40-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_H4 | PERIOD_H4 | Signal timeframe from the card. |
| strategy_macd_fast | 12 | 1-100 | Fast EMA period for MACD. |
| strategy_macd_slow | 26 | 2-200 | Slow EMA period for MACD. |
| strategy_macd_signal | 9 | 1-100 | Signal EMA period for MACD. |
| strategy_atr_period | 14 | 1-100 | ATR period for stop placement and stop-distance filter. |
| strategy_fractal_left | 3 | 3 | Older bars required to confirm each swing. |
| strategy_fractal_right | 3 | 3 | Newer bars required to confirm each swing. |
| strategy_divergence_lookback | 60 | 10-200 | Maximum H4 bars between the current scan and candidate swing points. |
| strategy_min_swing_separation_bars | 8 | 1-60 | Minimum bars between the two swing points. |
| strategy_confirmation_bars | 5 | 1-20 | Maximum bars after the newer swing for MACD confirmation. |
| strategy_sl_atr_mult | 0.5 | 0.1-5.0 | ATR offset beyond the divergence swing for SL. |
| strategy_max_stop_atr_mult | 3.0 | 0.5-10.0 | Reject entries with stop distance above this ATR multiple. |
| strategy_take_profit_r | 2.0 | 0.5-10.0 | Primary take-profit in units of initial risk. |
| strategy_opposite_swing_lookback | 20 | 5-100 | Lookback for nearer opposite swing TP. |
| strategy_max_hold_bars | 40 | 1-200 | Time exit in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major FX pair in the card's R3 P2 basket.
- GBPUSD.DWX - Major FX pair in the card's R3 P2 basket.
- USDJPY.DWX - Major FX pair in the card's R3 P2 basket.
- XAUUSD.DWX - Liquid gold CFD in the card's R3 P2 basket.

**Explicitly NOT for:**
- Symbols outside the card's R3 P2 basket - not approved for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | H4 swing hold, capped at 40 H4 bars |
| Expected drawdown profile | Mean-reversion drawdown clustered during persistent one-way trends |
| Regime preference | Mean-reversion after swing divergence |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO article
**Pointer:** https://ftmo.com/en/blog/technical-analysis-moving-average-convergence-divergence/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10979_ftmo-macd-div.md`

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
| v1 | 2026-06-06 | Initial build from card | 706650c5-8d3d-4a64-9b2a-17bc64d8cb74 |
