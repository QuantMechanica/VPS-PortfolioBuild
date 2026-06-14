# QM5_10746_tv-smart-pivot - Strategy Spec

**EA ID:** QM5_10746
**Slug:** tv-smart-pivot
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA tracks the most recent confirmed pivot high and pivot low using a 20-bar pivot window. A long trade is opened when the last closed M15 candle crosses above the latest confirmed pivot high; a short trade is opened when it crosses below the latest confirmed pivot low. Stop distance is the larger of 0.75 * ATR(14) and the configured fixed percent distance from entry. Take profit is fixed at 2.0R, with at least 20 bars required before another same-direction entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_pivot_period | 20 | 2-200 | Confirmed pivot left/right bar count used for breakout levels. |
| strategy_atr_period | 14 | 1-200 | ATR period for the volatility stop component. |
| strategy_atr_sl_mult | 0.75 | 0.1-10.0 | ATR multiplier used in the stop-distance max rule. |
| strategy_sl_percent | 1.0 | 0.01-20.0 | Fixed percent stop-distance component from entry price. |
| strategy_rr_target | 2.0 | 0.1-10.0 | Take-profit multiple of the selected stop distance. |
| strategy_min_same_dir_bars | 20 | 0-500 | Minimum closed bars before another entry in the same direction. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major FX pair in the approved R3 basket; OHLC pivot breakouts are directly testable.
- GBPUSD.DWX - Major FX pair in the approved R3 basket; OHLC pivot breakouts are directly testable.
- XAUUSD.DWX - Liquid metal in the approved R3 basket; pivot/ATR structure is directly testable.
- NDX.DWX - Liquid index CFD in the approved R3 basket; pivot/ATR structure is directly testable.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card; governed by 2R TP, stop loss, and Friday close. |
| Expected drawdown profile | Not specified in card; fixed 1R losses with 2R winners. |
| Regime preference | Breakout / volatility-expansion pivot regime. |
| Win rate target (qualitative) | Medium-low acceptable because baseline target is 2.0R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/IMTwV7U8/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10746_tv-smart-pivot.md`

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
| v1 | 2026-06-14 | Initial build from card | 0b869c07-ffa1-4e04-a1fd-a06d95a0a107 |
