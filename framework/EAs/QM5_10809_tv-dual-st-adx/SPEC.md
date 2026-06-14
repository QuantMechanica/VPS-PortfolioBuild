# QM5_10809_tv-dual-st-adx - Strategy Spec

**EA ID:** QM5_10809
**Slug:** tv-dual-st-adx
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a dual SuperTrend trend-following signal on confirmed H1 or H4 bars. It opens long when both the fast and slow SuperTrend states are bullish and ADX(14) is rising across the configured rising window. It opens short when both SuperTrend states are bearish and ADX(14) is rising. Open trades are closed when either SuperTrend reverses, when ADX stops rising for three consecutive closed bars, or when the optional H1/H4 max-bars stop is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_st_atr_period | 10 | 2-200 | ATR lookback for the fast SuperTrend. |
| strategy_fast_st_multiplier | 3.0 | 0.1-10.0 | ATR multiplier for the fast SuperTrend. |
| strategy_slow_st_atr_period | 21 | 2-200 | ATR lookback for the slow SuperTrend. |
| strategy_slow_st_multiplier | 4.0 | 0.1-10.0 | ATR multiplier for the slow SuperTrend and trailing stop line. |
| strategy_adx_period | 14 | 2-100 | ADX lookback used for rising confirmation and flattening exit. |
| strategy_adx_rising_window | 1 | 1-3 | Number of consecutive closed bars that must show rising ADX for entry. |
| strategy_adx_floor | 0.0 | 0-100 | Optional ADX floor; 0 disables the floor for baseline. |
| strategy_adx_flat_exit_bars | 3 | 1-10 | Consecutive closed bars with non-rising ADX required to exit. |
| strategy_max_h1_bars | 120 | 0-1000 | Optional maximum H1 holding period; 0 disables it. |
| strategy_max_h4_bars | 80 | 0-1000 | Optional maximum H4 holding period; 0 disables it. |
| strategy_supertrend_warmup_bars | 80 | 20-500 | Bounded closed-bar warmup for SuperTrend state reconstruction. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 forex basket member with native DWX OHLC/ATR/ADX support.
- GBPUSD.DWX - Card R3 forex basket member with native DWX OHLC/ATR/ADX support.
- USDJPY.DWX - Card R3 forex basket member with native DWX OHLC/ATR/ADX support.
- XAUUSD.DWX - Canonical DWX metal symbol for the card's XAUUSD target.
- GDAXI.DWX - Canonical DWX DAX custom symbol used for the card's GER40 target.
- NDX.DWX - Card R3 index basket member with DWX OHLC/ATR/ADX support.
- WS30.DWX - Card R3 index basket member with DWX OHLC/ATR/ADX support.

**Explicitly NOT for:**
- GER40.DWX - Not present in `dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.
- XAUUSD - Unsuffixed symbol is not used in research/backtest artifacts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 and H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Up to 120 H1 bars or 80 H4 bars unless SuperTrend or ADX exit fires earlier. |
| Expected drawdown profile | Trend-following profile with losses clustered in low-range chop. |
| Regime preference | Persistent directional trend / volatility-trailing regime. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/a9bKiHqV/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10809_tv-dual-st-adx.md`

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
| v1 | 2026-06-14 | Initial build from card | e45b9866-c230-4212-9d4a-53f777048f0e |
