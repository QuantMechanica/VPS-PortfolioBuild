# QM5_10472_mql5-plateau - Strategy Spec

**EA ID:** QM5_10472
**Slug:** `mql5-plateau`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades the Plateau MA cross with Bollinger filter on the current H1 chart. A long entry is generated when the fast LWMA was below the slow LWMA two closed bars ago, is above it on the last closed bar, and the last closed close is below the lower Bollinger Band. A short entry is generated when the fast LWMA was above the slow LWMA two closed bars ago, is below it on the last closed bar, and the last closed close is above the source-stated lower Bollinger threshold. Open positions close on the opposite signal, with initial stop at 1.5 ATR(14) and take profit at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 9 | 1-500 | Fast LWMA period. |
| `strategy_slow_ma_period` | 24 | 2-1000 | Slow LWMA period; must exceed fast period. |
| `strategy_bb_period` | 150 | 2-1000 | Bollinger Band period. |
| `strategy_bb_deviation` | 1.0 | 0.1-10.0 | Bollinger Band standard deviation multiplier. |
| `strategy_atr_period` | 14 | 1-500 | ATR period for initial stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for initial stop distance. |
| `strategy_rr_tp` | 2.0 | 0.1-10.0 | Take profit multiple of initial risk. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Primary symbol named by the card and source H1 note.
- `GBPUSD.DWX` - Liquid DWX FX major suitable for MA and Bollinger signals.
- `USDJPY.DWX` - Liquid DWX FX major suitable for MA and Bollinger signals.
- `USDCHF.DWX` - Liquid DWX FX major suitable for MA and Bollinger signals.
- `USDCAD.DWX` - Liquid DWX FX major suitable for MA and Bollinger signals.
- `AUDUSD.DWX` - Liquid DWX FX major suitable for MA and Bollinger signals.
- `NZDUSD.DWX` - Liquid DWX FX major suitable for MA and Bollinger signals.
- `XAUUSD.DWX` - Card explicitly includes XAUUSD after the FX majors.

**Explicitly NOT for:**
- `SP500.DWX` - Card targets FX majors and XAUUSD, not indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `Moderate reversal-system drawdowns during persistent trends.` |
| Regime preference | `trend-reversal with Bollinger filter` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23556`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10472_mql5-plateau.md`

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
| v1 | 2026-05-28 | Initial build from card | 22d0740c-2230-4d33-9563-830a0cc0fab0 |
