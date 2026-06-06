# QM5_10978_ftmo-macd-x — Strategy Spec

**EA ID:** QM5_10978
**Slug:** ftmo-macd-x
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 MACD momentum continuation. A long setup starts when MACD(12,26,9) crosses above its signal line, MACD is already above zero or crosses above zero within the next three H4 bars, and EMA(50) is rising over ten bars. Shorts use the inverse rules. Entries are skipped when ATR(14) is below its 20th percentile over the prior 120 bars, when the entry candle range is more than 2.5 ATR, or when the central high-impact news filter blocks trading. Stops use the recent 10-bar swing plus a 0.5 ATR buffer, target is 2.5R, the stop moves to breakeven after a 1.2R touch, and positions close on an opposite MACD signal cross or after 50 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_H4 | H4 fixed for P2 baseline | Signal timeframe from the card. |
| strategy_macd_fast | 12 | 1-100 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 2-200 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1-100 | MACD signal smoothing period. |
| strategy_ema_period | 50 | 2-300 | EMA trend filter period. |
| strategy_ema_slope_bars | 10 | 1-100 | Bars used to confirm EMA slope direction. |
| strategy_atr_period | 14 | 1-100 | ATR period for volatility filters and stop buffer. |
| strategy_atr_percentile_bars | 120 | 20-500 | Lookback used for the ATR percentile filter. |
| strategy_min_atr_percentile | 0.20 | 0.00-1.00 | Minimum ATR percentile threshold. |
| strategy_swing_lookback_bars | 10 | 2-100 | Swing high or low lookback for stop placement. |
| strategy_stop_atr_buffer_mult | 0.50 | 0.00-5.00 | ATR buffer beyond the swing stop. |
| strategy_take_profit_r | 2.50 | 0.10-10.00 | Profit target as R multiple. |
| strategy_breakeven_trigger_r | 1.20 | 0.10-10.00 | R multiple that triggers breakeven stop movement. |
| strategy_zero_confirm_bars | 3 | 0-10 | Bars allowed after signal cross for zero-line confirmation. |
| strategy_max_hold_bars | 50 | 1-500 | Maximum H4 bars to hold a trade. |
| strategy_max_entry_range_atr | 2.50 | 0.10-20.00 | Maximum closed entry candle range in ATR units. |
| strategy_max_spread_points | 0 | 0-100000 | Optional spread ceiling; 0 disables the extra spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — card R3 basket includes liquid DWX forex majors.
- GBPUSD.DWX — card R3 basket includes liquid DWX forex majors.
- USDJPY.DWX — card R3 basket includes liquid DWX forex majors.
- XAUUSD.DWX — card R3 basket includes DWX gold for MACD momentum testing.

**Explicitly NOT for:**
- SP500.DWX — not in this card's R3 FX/metals basket.
- NDX.DWX — not in this card's R3 FX/metals basket.
- WS30.DWX — not in this card's R3 FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the V5 framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | H4 signal holds, capped at 50 H4 bars |
| Expected drawdown profile | Trend-following momentum with losses controlled by structure-plus-ATR stops |
| Regime preference | Trend-following momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, Technical Analysis - Moving Average Convergence/Divergence, 2022-11-18, https://ftmo.com/en/blog/technical-analysis-moving-average-convergence-divergence/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10978_ftmo-macd-x.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 8f887324-fc5d-47a8-a629-ba2393910f8f |
