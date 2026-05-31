# QM5_10556_mql5-3rvi - Strategy Spec

**EA ID:** QM5_10556
**Slug:** `mql5-3rvi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades a three-timeframe Relative Vigor Index confirmation pattern. A long entry is opened when the medium and higher timeframe RVI main lines are above their signal lines, and the lower timeframe RVI crosses upward through its signal line on a closed bar. A short entry is opened when the medium and higher timeframe RVI main lines are below their signal lines, and the lower timeframe RVI crosses downward through its signal line on a closed bar. Open positions close on the opposite lower-timeframe RVI cross, or by the ATR hard stop, 1.5R target, Friday close, news filter, or kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lower_tf` | `PERIOD_M5` | M5-H1 | Lower timeframe used for RVI cross entry and opposite-cross exit. |
| `strategy_medium_tf` | `PERIOD_M15` | M5-H1 | Medium timeframe used for RVI trend alignment. |
| `strategy_higher_tf` | `PERIOD_M30` | M15-H4 | Higher timeframe used for RVI trend alignment and ATR stop reference. |
| `strategy_rvi_period` | `10` | 2-50 | RVI smoothing period. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `1.5` | 0.25-10.0 | ATR multiple for stop distance. |
| `strategy_rr_target` | `1.5` | 0.25-10.0 | Take-profit multiple of initial risk. |
| `strategy_adx_period` | `14` | 2-100 | ADX period for the optional trend-strength floor. |
| `strategy_adx_floor` | `0.0` | 0.0-100.0 | Optional ADX minimum; 0 disables this filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source test was EURUSD and the card includes it in the primary P2 basket.
- `GBPUSD.DWX` - Major FX pair with standard RVI support and included in the card's P2 basket.
- `USDJPY.DWX` - Major FX pair with standard RVI support and included in the card's P2 basket.
- `XAUUSD.DWX` - Liquid metals symbol with standard RVI support and included in the card's P2 basket.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not valid DWX backtest targets for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `M5` lower RVI cross, `M15` medium RVI alignment, `M30` higher RVI alignment and ATR stop |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday to multi-session, closed by opposite lower-timeframe RVI cross or 1.5R bracket. |
| Expected drawdown profile | Moderate oscillator-cross drawdown controlled by ATR hard stops. |
| Regime preference | Multi-timeframe trend continuation with lower-timeframe momentum confirmation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/16733`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10556_mql5-3rvi.md`

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
| v1 | 2026-05-29 | Initial build from card | f5c0388e-64c6-44ef-82cc-9690986181f0 |
