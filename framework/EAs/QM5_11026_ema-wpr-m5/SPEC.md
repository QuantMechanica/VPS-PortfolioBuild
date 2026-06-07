# QM5_11026_ema-wpr-m5 - Strategy Spec

**EA ID:** QM5_11026
**Slug:** ema-wpr-m5
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed M5 bars. A long signal requires the latest closed close to be above EMA(144), Williams Percent R(46) to cross upward through -80, and the WPR retracement rule to be satisfied since the last long entry. A short signal requires the close to be below EMA(144), WPR(46) to cross downward through -20, and the matching short retracement rule to be satisfied. Positions exit by fixed SL/TP, by WPR crossing out of the opposite extreme, by the unprofitable-trade timeout, or by framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_use_ema_trend | true | true/false | Require the EMA trend filter for entries. |
| strategy_ema_period | 144 | 89-233 | EMA period used as the directional filter. |
| strategy_bars_in_trend | 1 | 1+ | Number of completed bars that must be on the EMA trend side. |
| strategy_wpr_period | 46 | 21-72 | Williams Percent R lookback period. |
| strategy_wpr_oversold | -80.0 | -85 to -75 | Oversold threshold for long entry and short exit. |
| strategy_wpr_overbought | -20.0 | -25 to -15 | Overbought threshold for short entry and long exit. |
| strategy_wpr_retracement_points | 30.0 | 20-40 | Minimum WPR retracement since last same-direction entry. |
| strategy_sl_points | 50 | 30-80 | Fixed stop-loss distance in broker points. |
| strategy_tp_points | 200 | 0-200 | Fixed take-profit distance in broker points; 0 disables TP. |
| strategy_use_wpr_exit | true | true/false | Enable WPR opposite-extreme cross exits. |
| strategy_use_unprofit_exit | true | true/false | Enable the unprofitable-trade bar timeout. |
| strategy_max_unprofit_bars | 5 | 0-10 | Bars after entry before closing a never-profitable trade. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card primary M5 FX optimization target and DWX-supported forex symbol.
- GBPUSD.DWX - same FX indicator mechanics and included in the card's P2 basket.
- USDJPY.DWX - same FX indicator mechanics and included in the card's P2 basket.
- XAUUSD.DWX - DWX-supported liquid metal symbol included in the card's P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the build and backtest workflow requires canonical `.DWX` symbols.
- Equity index symbols - not listed in this card's R3 P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | M5 signal holding period, generally minutes to hours until WPR exit, SL, TP, or timeout |
| Expected drawdown profile | Fast oscillator entries can overtrade in choppy M5 regimes; loss is bounded by fixed SL and one active position |
| Regime preference | EMA trend with oscillator reversal entries |
| Win rate target (qualitative) | medium |

Card expected frequency: M5 EMA-trend plus WPR oscillator signals, bounded to one active trade; conservative estimate 80-180 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article and CodeBase entry
**Pointer:** https://www.mql5.com/en/articles/529 and https://www.mql5.com/en/code/10413
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11026_ema-wpr-m5.md`

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
| v1 | 2026-06-07 | Initial build from card | 3756c734-c54b-4ef0-8975-1fd2c8708c66 |
