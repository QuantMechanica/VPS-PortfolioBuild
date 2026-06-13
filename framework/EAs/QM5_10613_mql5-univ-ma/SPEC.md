# QM5_10613_mql5-univ-ma - Strategy Spec

**EA ID:** QM5_10613
**Slug:** mql5-univ-ma
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On each completed bar, the EA calculates an EMA and an LWMA over the same close-price smoothing period. It enters long when EMA is above LWMA and both averages are rising versus the prior completed bar. It enters short when EMA is below LWMA and both averages are falling. Open positions close when the EMA/LWMA relationship reverses, or after 24 completed H4 bars without a reverse signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 20 | `> 1` | Shared EMA and LWMA smoothing period. |
| `strategy_atr_period` | 14 | `> 0` | ATR period for catastrophic stop distance. |
| `strategy_atr_sl_mult` | 2.5 | `> 0.0` | ATR multiplier for the initial catastrophic stop. |
| `strategy_max_hold_h4_bars` | 24 | `> 0` | Maximum hold time, expressed as completed H4 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX major with native OHLC history for MA calculations.
- `GBPUSD.DWX` - card-listed DWX FX major with native OHLC history for MA calculations.
- `USDJPY.DWX` - card-listed DWX FX major with native OHLC history for MA calculations.
- `XAUUSD.DWX` - card-listed DWX gold CFD with native OHLC history for MA calculations.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not broker/custom-symbol verified for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 24 completed H4 bars unless the EMA/LWMA reverse exit fires first. |
| Expected drawdown profile | Trend-following whipsaw risk in sideways regimes; bounded by 2.5 ATR catastrophic stop. |
| Regime preference | Moving-average trend direction. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1076 and `artifacts/cards_approved/QM5_10613_mql5-univ-ma.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10613_mql5-univ-ma.md`

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
| v1 | 2026-06-13 | Initial build from card | 3de24468-a323-482f-9d14-80dd436865be |
