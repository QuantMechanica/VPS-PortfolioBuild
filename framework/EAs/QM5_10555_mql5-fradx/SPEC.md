# QM5_10555_mql5-fradx - Strategy Spec

**EA ID:** QM5_10555
**Slug:** mql5-fradx
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades closed-bar directional-line crosses from the ADX family. It opens long when DI+ crosses above DI- on the configured signal timeframe, and opens short when DI- crosses above DI+. Existing long positions close on a bearish DI cross, existing short positions close on a bullish DI cross, and all trades also use the framework stop, target, news, Friday-close, and kill-switch controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H12` | H6/H12/D1 sweep | Timeframe used for DI cross signal reads. |
| `strategy_e_period` | `14` | `2-100` | ADX/DI period standing in for the card's Fractal_ADX_Cloud `e_period`. |
| `strategy_adx_min` | `0.0` | `0-50` | Optional ADX main-line minimum; `0` disables the filter. |
| `strategy_atr_period` | `14` | `2-100` | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | `0.5-10.0` | Stop distance as a multiple of ATR. |
| `strategy_target_r_multiple` | `1.5` | `0.5-10.0` | Profit target distance in initial risk multiples. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - card primary source test and matrix-valid FX major.
- `EURUSD.DWX` - matrix-valid FX major with portable price-derived DI signal.
- `GBPUSD.DWX` - matrix-valid FX major with portable price-derived DI signal.
- `XAUUSD.DWX` - matrix-valid metal with portable price-derived DI signal.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick-data registration is allowed.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H12` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `Trend-following DI crosses should take occasional whipsaws in ranging markets, bounded by ATR stop and 1.5R target.` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/17027
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10555_mql5-fradx.md`

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
| v1 | 2026-05-29 | Initial build from card | fc0b33b0-74d2-40f4-ba40-eb497eb0788e |
