# QM5_11088_coppock-turn - Strategy Spec

**EA ID:** QM5_11088
**Slug:** `coppock-turn`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA computes the Coppock curve as LWMA(10) of ROC(14) plus ROC(11), using completed H4 closes. It opens long when the Coppock curve had been falling, turns upward, and the current completed-bar value remains below zero. It opens short when the curve had been rising, turns downward, and the current completed-bar value remains above zero. Long positions close on the opposite strict short turn or after 30 H4 bars; short positions close on the opposite strict long turn or after 30 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roc1_period` | 14 | `> 0` | First Coppock ROC lookback. |
| `strategy_roc2_period` | 11 | `> 0` | Second Coppock ROC lookback. |
| `strategy_lwma_period` | 10 | `> 0` | LWMA period applied to ROC(14)+ROC(11). |
| `strategy_atr_period` | 14 | `> 0` | ATR period for catastrophic stop placement. |
| `strategy_atr_sl_mult` | 2.5 | `> 0` | ATR multiplier for catastrophic stop distance. |
| `strategy_max_hold_bars` | 30 | `> 0` | Maximum holding period in H4 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 basket includes liquid DWX EUR/USD forex exposure.
- `GBPUSD.DWX` - card R3 basket includes liquid DWX GBP/USD forex exposure.
- `USDJPY.DWX` - card R3 basket includes liquid DWX USD/JPY forex exposure.
- `XAUUSD.DWX` - card R3 basket includes liquid DWX gold CFD exposure.

**Explicitly NOT for:**
- `SP500.DWX` - not in the card's R3 Coppock baseline basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | Up to `30` H4 bars by card time stop. |
| Expected drawdown profile | Catastrophic ATR stop limits failed oscillator turns. |
| Regime preference | Momentum-turn / oscillator-reversal regimes. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub repository / indicator source`
**Pointer:** `https://github.com/EarnForex/Coppock`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11088_coppock-turn.md`

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
| v1 | 2026-06-07 | Initial build from card | 11223b89-af10-4392-a206-c5159bb62c84 |
