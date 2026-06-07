# QM5_11063_atc-macd-reverse - Strategy Spec

**EA ID:** QM5_11063
**Slug:** atc-macd-reverse
**Source:** de2146db-4632-5883-8994-7f300669caa8
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades the ATC 2011 MACD reverse rule on H1. It opens long when MACD main crosses upward through zero on the just-closed H1 bar, or when MACD main is above zero and the MACD signal line forms a local trough. It opens short on the inverse zero-line cross or signal-line peak. Open positions exit by broker TP, ATR stop, opposite MACD direction, framework Friday close, or a 10-bar H1 time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_macd_fast | 30 | 20-40 in P3 | MACD fast EMA period from the card baseline. |
| strategy_macd_slow | 500 | 300-700 in P3 | MACD slow EMA period from the card baseline. |
| strategy_macd_signal | 36 | 24-48 in P3 | MACD signal period from the card baseline. |
| strategy_tp_points | 2200 | 1200-3200 in P3 | Fixed take-profit distance in raw symbol points. |
| strategy_atr_period | 14 | fixed baseline | ATR period for the V5 protective stop. |
| strategy_atr_sl_mult | 2.0 | 1.5-2.5 in P3 | ATR multiple for the protective stop. |
| strategy_time_stop_bars | 10 | 0, 10, 20 in P3 | Maximum H1 bars to hold before closing. |
| strategy_median_spread_pts | 20 | symbol calibrated | Baseline median spread in points for the card's 2x spread filter. |
| strategy_spread_max_mult | 2.0 | fixed baseline | Maximum current spread as a multiple of the median spread input. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card states the source EURUSD H1 strategy ports directly to DWX FX symbols.
- GBPUSD.DWX - Included in the approved R3 P2 FX basket.
- USDJPY.DWX - Included in the approved R3 P2 FX basket.
- EURJPY.DWX - Included in the approved R3 P2 FX basket.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - The approved card is an H1 FX MACD strategy and R3 lists only FX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 10 H1 bars unless TP, SL, or opposite MACD signal exits first. |
| Expected drawdown profile | Bounded by 2.0 x ATR(14,H1) protective stop and fixed-risk sizing. |
| Regime preference | Trend reversal and MACD momentum turns. |
| Win rate target (qualitative) | Medium; low-activity source with fixed TP and reversal exits. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** de2146db-4632-5883-8994-7f300669caa8
**Source type:** MQL5 CodeBase and MQL5 article
**Pointer:** https://www.mql5.com/en/code/611 and https://www.mql5.com/en/articles/547
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11063_atc-macd-reverse.md`

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
| v1 | 2026-06-07 | Initial build from card | 7b91be8c-7f95-4348-8c73-4ad0b07f6549 |
