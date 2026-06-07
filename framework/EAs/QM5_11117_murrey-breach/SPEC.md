# QM5_11117_murrey-breach - Strategy Spec

**EA ID:** QM5_11117
**Slug:** murrey-breach
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA calculates Murrey Math lines from the rolling high and low over 64 D1-equivalent periods, using the source default `StepBack = 0`. On each completed H4 bar it watches only the primary `[0/8]` through `[8/8]` levels. It buys at the next bar open when the completed close breaches upward through one of those levels, and sells when the completed close breaches downward. It closes when price closes back through the breached level, when an opposite breach appears, or when 12 H4 bars have passed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_murrey_period` | 64 | 16-256 | Number of upper-timeframe periods used to calculate Murrey levels. |
| `strategy_upper_timeframe` | PERIOD_D1 | PERIOD_H4-PERIOD_D1 | Upper timeframe used to translate the source Murrey lookback onto the chart timeframe. |
| `strategy_step_back` | 0 | 0-20 | Source Murrey StepBack offset for the high/low window. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for the stop cap and minimum interval filter. |
| `strategy_atr_stop_cap_mult` | 2.5 | 0.5-6.0 | Maximum stop distance as a multiple of ATR. |
| `strategy_min_interval_atr_mult` | 0.5 | 0.1-3.0 | Blocks trades when one Murrey interval is smaller than this ATR multiple. |
| `strategy_max_hold_bars` | 12 | 1-48 | Maximum holding period in H4 bars before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Liquid major FX pair in the card's R3 basket.
- GBPUSD.DWX - Liquid major FX pair in the card's R3 basket.
- USDJPY.DWX - Liquid major FX pair in the card's R3 basket.
- XAUUSD.DWX - Liquid gold symbol in the card's R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline runs require canonical `.DWX` symbols.
- Symbols outside the approved R3 basket - not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | PERIOD_D1 Murrey lookback expansion |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Up to 12 H4 bars |
| Expected drawdown profile | Breakout trades can cluster losses during false breaches and low-range conditions. |
| Regime preference | Breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 indicator source
**Pointer:** https://github.com/EarnForex/Murrey-Math-Line-X and `artifacts/cards_approved/QM5_11117_murrey-breach.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11117_murrey-breach.md`

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
| v1 | 2026-06-07 | Initial build from card | 2e75b9f7-731f-4daf-b540-6a89d4d60fef |
