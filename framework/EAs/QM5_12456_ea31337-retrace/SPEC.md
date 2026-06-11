# QM5_12456_ea31337-retrace - Strategy Spec

**EA ID:** QM5_12456
**Slug:** ea31337-retrace
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades EA31337's Ichimoku pivot retracement setup on closed D1 bars. It computes source-style classic D1 pivot support and resistance levels from the prior D1 bar using the high/low-aware applied price, then reads Tenkan-sen with periods 30/10/30 and shift 1. A long entry requires the prior D1 bar to be bullish, Tenkan-sen to be rising, and Tenkan-sen to be within 4 percent of the prior day's S1-S4 support levels. A short entry requires the prior D1 bar to be bearish, Tenkan-sen to be falling, and the same source-literal support proximity check; exits are fixed SL/TP, a 30-bar time stop, Friday close, or a cached opposite retracement signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_max_spread_pips | 4.0 | >0 | Maximum spread allowed before the no-trade filter blocks entry. |
| strategy_signal_shift | 1 | >=1 | Closed chart bar used for Ichimoku signal evaluation. |
| strategy_pivot_shift | 1 | >=1 | Closed D1 bar used to compute prior-period pivot levels. |
| strategy_tenkan_period | 30 | >=1 | Source default Ichimoku Tenkan-sen period. |
| strategy_kijun_period | 10 | >=1 | Source default Ichimoku Kijun-sen period. |
| strategy_senkou_b_period | 30 | >=1 | Source default Ichimoku Senkou Span B period. |
| strategy_signal_open_level | 4.0 | >=0 | Percent of prior D1 range allowed between Tenkan-sen and nearest S1-S4 support level. |
| strategy_signal_open_method | 0 | integer mask | Source signal-open method mask; bit 0 enables the four-bar local extreme check. |
| strategy_close_loss_pips | 80.0 | >0 | Fixed stop-loss fallback distance matching the source close-loss default. |
| strategy_close_profit_pips | 80.0 | >0 | Fixed take-profit fallback distance matching the source close-profit default. |
| strategy_close_after_bars | 30 | >0 | Maximum hold time in chart bars, matching source close time -30 bars. |
| strategy_price_stop_level | 2.0 | >=0 | Percent of prior D1 range used as offset around pivot-derived stop and target levels. |
| strategy_atr_period | 14 | >=1 | ATR period used when pivot stop placement is invalid. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiplier for the fallback protective stop. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair in the card's suggested first universe.
- GBPUSD.DWX - liquid major FX pair in the card's suggested first universe.
- USDJPY.DWX - liquid major FX pair in the card's suggested first universe.
- XAUUSD.DWX - liquid metal CFD in the card's suggested first universe.
- GDAXI.DWX - verified DWX DAX equivalent for the card's unavailable DAX.DWX symbol.

**Explicitly NOT for:**
- DAX.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | D1 pivot calculation and D1 Ichimoku Tenkan-sen signal reads |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Up to 30 D1 bars |
| Expected drawdown profile | Retracement losses cluster when price trends away from prior-day pivot support zones. |
| Regime preference | Pivot-level retracement with Ichimoku line direction confirmation. |
| Win rate target (qualitative) | Not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** GitHub repository
**Pointer:** https://github.com/EA31337/Strategy-Retracement/blob/master/Stg_Retracement.mqh
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12456_ea31337-retrace.md`

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
| v1 | 2026-06-11 | Initial build from card | 42129461-8f71-44a8-bb91-f4e52f177888 |
