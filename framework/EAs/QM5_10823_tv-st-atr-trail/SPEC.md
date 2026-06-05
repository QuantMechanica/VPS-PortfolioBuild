# QM5_10823_tv-st-atr-trail - Strategy Spec

**EA ID:** QM5_10823
**Slug:** tv-st-atr-trail
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades SuperTrend flips on the chart timeframe. It calculates a SuperTrend line from closed-bar OHLC data using Wilder ATR, an ATR period, and a multiplier. It opens long when the closed-bar SuperTrend state flips from bearish to bullish, opens short when it flips from bullish to bearish, and keeps at most one position per symbol and magic. The initial stop is ATR-based; once price has moved far enough in favor, the stop is tightened to the cached SuperTrend line, and an opposite SuperTrend state or market cross of the line closes the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 10-21 card test band | ATR period used for SuperTrend and initial stop. |
| strategy_supertrend_multiplier | 3.0 | 2.0-4.0 card test band | ATR multiplier for the SuperTrend reversal line. |
| strategy_initial_stop_atr_mult | 2.0 | 1.5-2.5 card test band | Initial stop distance in ATR multiples. |
| strategy_tighten_threshold_pct | 1.0 | 0.5-1.0 card test band | Favorable percent move before tightening stop to the SuperTrend line. |
| strategy_tighten_mode | 0 | 0-1 | 0 uses percent threshold; 1 uses ATR threshold. |
| strategy_tighten_atr_mult | 1.0 | 1.0 card test value | ATR multiple used when strategy_tighten_mode is 1. |
| strategy_position_mode | 2 | 0-2 | 0 long-only, 1 short-only, 2 both directions. |
| strategy_supertrend_lookback | 160 | >=75 | Closed-bar history used to warm up the SuperTrend calculation. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary forex basket member.
- GBPUSD.DWX - Card R3 primary forex basket member.
- USDJPY.DWX - Card R3 primary forex basket member.
- XAUUSD.DWX - DWX matrix canonical gold symbol for the card's XAUUSD entry.
- GDAXI.DWX - DWX matrix canonical DAX symbol replacing the card's unavailable GER40.DWX name.
- NDX.DWX - Card R3 primary Nasdaq 100 index member.
- WS30.DWX - Card R3 primary Dow 30 index member.

**Explicitly NOT for:**
- GER40.DWX - Not present in dwx_symbol_matrix.csv for this build; GDAXI.DWX is registered instead.
- XAUUSD - Unsuffixed symbol is not a DWX matrix symbol; XAUUSD.DWX is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Hours to days, governed by SuperTrend reversal and trailing stop. |
| Expected drawdown profile | Classic trend-following stop-and-reverse drawdown during range-bound chop. |
| Regime preference | Trend-following volatility continuation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/L9GkARD2-SUPERTREND-ATR-WITH-TRAILING-STOP-LOSS/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10823_tv-st-atr-trail.md`

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
| v1 | 2026-06-05 | Initial build from card | 2c885668-917a-47c8-90f7-50617169b62d |
