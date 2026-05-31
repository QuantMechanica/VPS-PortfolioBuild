# QM5_10565_mql5-rvidiff - Strategy Spec

**EA ID:** QM5_10565
**Slug:** `mql5-rvidiff`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades closed-bar RVIDiff histogram direction changes on H6. A long entry is opened when the closed histogram turns from falling to rising, and a short entry is opened when it turns from rising to falling. Open positions close on the opposite histogram turn, or by the ATR hard stop, 1.5R target, Friday close, news filter, or kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H6` | H4-H12 | Timeframe used for the RVIDiff histogram turn and ATR bracket. |
| `strategy_rvi_period` | `10` | 2-50 | RVI smoothing period used to derive the RVIDiff histogram. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | 0.5-10.0 | ATR multiplier for the hard stop. |
| `strategy_rr_target` | `1.5` | 0.5-10.0 | Reward/risk multiple for the take-profit target. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `USDCAD.DWX` - Source test symbol and part of the card's primary P2 basket.
- `EURUSD.DWX` - Major FX pair included in the card's primary P2 basket.
- `GBPUSD.DWX` - Major FX pair included in the card's primary P2 basket.
- `XAUUSD.DWX` - Liquid metals symbol included in the card's primary P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - not available under the Darwinex custom-symbol registry used by the V5 pipeline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Multi-bar H6 holds until opposite RVIDiff turn or ATR bracket. |
| Expected drawdown profile | Moderate oscillator-turn drawdowns bounded by 2.0 ATR hard stop. |
| Regime preference | Momentum direction-change regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/16222`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10565_mql5-rvidiff.md`

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
| v1 | 2026-05-29 | Initial build from card | 9d0d3c57-eebf-4f70-8899-259c178b099f |
