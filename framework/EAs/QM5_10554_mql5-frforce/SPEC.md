# QM5_10554_mql5-frforce - Strategy Spec

**EA ID:** QM5_10554
**Slug:** `mql5-frforce`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a Fractal Force Index on closed H4 bars. It opens long when the index crosses upward through zero and opens short when the index crosses downward through zero, provided there is no existing position for the same symbol and magic. Long positions close on a downward zero cross, short positions close on an upward zero cross, or through the ATR stop, 1.5R target, Friday close, news, and kill-switch framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_e_period` | 30 | 2-200 | Fractal dimension lookback used to adapt the force-index smoothing speed. |
| `strategy_normal_speed` | 30 | 1-200 | Base smoothing speed before fractal adjustment. |
| `strategy_ma_method` | `MODE_SMA` | `MODE_SMA`, `MODE_EMA`, `MODE_SMMA`, `MODE_LWMA` | Moving-average method used inside the Fractal Force Index. |
| `strategy_volume_type` | `VOLUME_TICK` | `VOLUME_TICK`, `VOLUME_REAL` | Volume input used to scale the force-index value. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for the hard stop. |
| `strategy_rr_target` | 1.5 | 0.1-10.0 | Reward/risk target multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented
> here. Only strategy-specific inputs are listed.

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` - Card primary source test pair and a matrix-valid liquid FX cross.
- `EURUSD.DWX` - Matrix-valid liquid major FX pair suitable for H4 force-index crosses.
- `GBPUSD.DWX` - Matrix-valid liquid major FX pair suitable for H4 force-index crosses.
- `USDJPY.DWX` - Matrix-valid liquid major FX pair suitable for H4 force-index crosses.

**Explicitly NOT for:**
- Non-DWX symbols - not registered in the V5 symbol matrix for this EA.
- Equity indices and commodities - the approved card's R3 basket is FX-only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Several H4 bars to a few days, until the opposite zero cross or stop/target. |
| Expected drawdown profile | Moderate FX trend/momentum drawdown, bounded by ATR hard stops. |
| Regime preference | Trend / momentum continuation after force-index zero cross. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17042`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10554_mql5-frforce.md`

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
| v1 | 2026-05-29 | Initial build from card | 1e72946d-7e39-4fcc-b1e4-b2961d5efe5f |
