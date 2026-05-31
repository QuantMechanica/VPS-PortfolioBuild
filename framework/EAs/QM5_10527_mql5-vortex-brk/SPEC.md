# QM5_10527_mql5-vortex-brk - Strategy Spec

**EA ID:** QM5_10527
**Slug:** `mql5-vortex-brk`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA calculates Vortex Indicator VI+ and VI- on closed H1 bars using period 14 by default. A bullish VI+ cross above VI- registers the crossover bar high as a long breakout trigger, and a bearish VI- cross above VI+ registers the crossover bar low as a short breakout trigger. The EA enters at market after a later closed bar breaks that registered high or low, then exits on the opposite Vortex cross or by the protective SL/TP. The protective stop uses the farther of 1.5 ATR(14) and the opposite side of the crossover bar, capped at 2.5 ATR(14), with a 1.5R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_vortex_period` | 14 | 10-21 sweep baseline | Vortex Indicator lookback period. |
| `strategy_atr_period` | 14 | 10-30 | ATR lookback used for protective stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.5 | Baseline ATR stop multiple before structure comparison. |
| `strategy_atr_sl_cap_mult` | 2.5 | 1.5-3.5 | Maximum stop distance expressed as ATR multiple. |
| `strategy_tp_rr` | 1.5 | 1.0-3.0 | Take-profit reward-to-risk multiple. |
| `strategy_breakout_exp_bars` | 6 | 1-24 | Number of H1 bars a registered crossover breakout remains valid. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX forex major with H1 OHLC coverage for Vortex and ATR.
- `GBPUSD.DWX` - card-listed DWX forex major with H1 OHLC coverage for Vortex and ATR.
- `USDJPY.DWX` - card-listed DWX forex major with H1 OHLC coverage for Vortex and ATR.
- `XAUUSD.DWX` - card-listed DWX gold symbol with H1 OHLC coverage for Vortex and ATR.

**Explicitly NOT for:**
- Non-DWX symbols - the build and backtest registries require canonical DWX symbols.
- Symbols outside the card R3 basket - no portability claim was made for them in the approved card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | hours to days |
| Expected drawdown profile | Trend-breakout false starts can cluster during range-bound markets. |
| Regime preference | trend-following breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/19137`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10527_mql5-vortex-brk.md`

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
| v1 | 2026-05-29 | Initial build from card | 327d0dd8-0ec3-472f-b802-9d5751d570f0 |
