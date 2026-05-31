# QM5_10504_mql5-prevc-break - Strategy Spec

**EA ID:** QM5_10504
**Slug:** mql5-prevc-break
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades breakouts of the previous completed candle on a configured higher timeframe. A long signal occurs when the current ask trades above that candle's high plus an indent; a short signal occurs when the current bid trades below that candle's low minus an indent. When the moving-average filter is enabled, longs require the fast EMA to be above the slow EMA and shorts require the fast EMA to be below the slow EMA. Exits are fixed at a stop loss and a 1.5R take profit; the stop is the tighter of the opposite side of the previous candle and 1.5 times ATR(14), with a minimum stop-distance sanity check.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_breakdown_tf | PERIOD_H1 | M1-MN1 | Timeframe whose previous completed candle defines the breakout range. |
| strategy_indent_points | 10 | >=0 | Point offset added above the prior high or below the prior low before entry triggers. |
| strategy_ma_filter_enabled | true | true/false | Enables the fast/slow moving-average direction filter from the source. |
| strategy_fast_ma_period | 20 | >0 | Fast EMA period for the optional MA filter. |
| strategy_slow_ma_period | 50 | >0 | Slow EMA period for the optional MA filter. |
| strategy_atr_period | 14 | >0 | ATR period used for the stop-loss cap. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiplier used as the maximum structural stop distance. |
| strategy_take_profit_r | 1.5 | >0 | Fixed take-profit multiple of initial stop risk. |
| strategy_min_stop_points | 20 | >=1 | Minimum allowed stop distance in points after symbol sanity checks. |
| strategy_max_spread_points | 0 | >=0 | Optional spread filter in points; zero disables this filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card primary FX major with native DWX history.
- GBPUSD.DWX - card FX major with native DWX history.
- USDJPY.DWX - card FX major with native DWX history.
- XAUUSD.DWX - card metal symbol with native DWX history and breakout suitability.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use the canonical `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/test data is registered for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | strategy_breakdown_tf, default PERIOD_H1 |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Not specified in card; expected intraday to multi-hour from M15 execution and fixed SL/TP. |
| Expected drawdown profile | Breakout losses cluster in ranging periods; fixed-risk sizing controls per-trade loss. |
| Regime preference | Breakout / volatility expansion. |
| Win rate target (qualitative) | Medium, with 1.5R winners offsetting false breakouts. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** Vladimir Khlystov idea, Vladimir Karputov code, "Previous Candle Breakdown", MQL5 CodeBase, published 2018-06-18.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10504_mql5-prevc-break.md`

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
| v1 | 2026-05-28 | Initial build from card | ede7c56b-45cb-4733-8755-53624e0298c4 |
