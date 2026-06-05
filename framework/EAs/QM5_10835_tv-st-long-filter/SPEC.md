# QM5_10835_tv-st-long-filter - Strategy Spec

**EA ID:** QM5_10835
**Slug:** tv-st-long-filter
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades long only on the chart timeframe when SuperTrend flips from downtrend to uptrend on the last closed bar. The close must also be above the configured moving-average trend filter and above the active SuperTrend support line. The initial stop is the SuperTrend support line, skipped if the distance is wider than 2.5 x ATR(14), and the stop is trailed upward to new SuperTrend support while a long position is open. The EA closes the long when the cached SuperTrend state turns bearish or price reaches the active SuperTrend line; the optional safety target defaults to 3.0 x ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 10 | 7-14 tested | ATR period used for the SuperTrend line. |
| strategy_supertrend_multiplier | 3.0 | 2.0-4.0 tested | ATR multiplier used to place SuperTrend bands. |
| strategy_price_source | 0 | 0-1 | SuperTrend source, 0=hl2 and 1=close. |
| strategy_trend_ma_period | 100 | 100-200 tested | Period for the moving-average trend filter. |
| strategy_trend_ma_mode | 0 | 0-1 | Trend filter type, 0=SMA and 1=EMA. |
| strategy_stop_cap_atr_period | 14 | fixed baseline | ATR period for the maximum initial stop-distance cap. |
| strategy_stop_cap_atr_mult | 2.5 | fixed baseline | Maximum allowed initial stop distance in ATR units. |
| strategy_target_atr_period | 14 | fixed baseline | ATR period for the optional safety target. |
| strategy_target_atr_mult | 3.0 | 0.0-3.0 tested | Take-profit distance in ATR units, where 0 disables the target. |
| strategy_supertrend_lookback | 180 | >=55 | Closed-bar lookback used to recompute the SuperTrend state. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - matrix-available DAX proxy for the card-stated GER40.DWX trend-following target.
- NDX.DWX - liquid US index CFD suitable for SuperTrend long trend-following.
- XAUUSD.DWX - liquid metal CFD suitable for ATR and SuperTrend calculations.
- EURUSD.DWX - liquid FX pair suitable for OHLC, ATR, and moving-average filters.
- GBPUSD.DWX - liquid FX pair suitable for OHLC, ATR, and moving-average filters.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.
- SPX500.DWX, SPY.DWX, ES.DWX - not canonical DWX symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | hours to days |
| Expected drawdown profile | Whipsaw losses in sideways markets, with capped initial volatility stops. |
| Regime preference | trend-following / volatility-stop |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `SuperTrend Long Strategy +TrendFilter`, author handle `Julien_Exe`, published 2023-05-04.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10835_tv-st-long-filter.md`

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
| v1 | 2026-06-06 | Initial build from card | afde0e9f-e81c-4dca-ba9c-e1703ee816ec |
