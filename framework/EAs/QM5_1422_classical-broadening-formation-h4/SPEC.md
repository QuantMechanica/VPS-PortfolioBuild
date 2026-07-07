# QM5_1422_classical-broadening-formation-h4 - Strategy Spec

**EA ID:** QM5_1422
**Slug:** classical-broadening-formation-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA looks for a five-pivot broadening formation on closed H4 bars. The five pivots must alternate, expand with higher highs and lower lows, and produce a rising upper line plus falling lower line with no prior close outside the ATR-buffered bounds. When the structure is live at the right edge, the EA places an OCO buy-stop above the upper line and sell-stop below the lower line. It takes profit at 0.65 times the pattern amplitude, partially closes at 0.50 times amplitude, exits on a deep return into the pattern within five H4 bars, or exits after 35 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | >0 | ATR period for H4 buffers and D1 volatility regime. |
| strategy_pattern_min_bars | 50 | 50-150 | Minimum H4 lookback for the broadening pattern. |
| strategy_pattern_max_bars | 150 | 50-150 | Maximum H4 lookback for the broadening pattern. |
| strategy_pivot_span | 2 | fixed 2 | Williams 5-bar fractal side span. |
| strategy_pivot_amplitude_atr | 1.00 | >0 | Minimum adjacent pivot swing in ATR units. |
| strategy_divergence_atr_buffer | 0.50 | >=0 | ATR buffer required for expanding highs and lows. |
| strategy_slope_atr_per_bar_min | 0.05 | >0 | Minimum absolute trendline slope in ATR per H4 bar. |
| strategy_divergence_ratio_min | 1.20 | >0 | Minimum divergence ratio between upper and lower slopes. |
| strategy_prior_break_atr_buffer | 0.50 | >=0 | Close-through buffer that invalidates already-broken patterns. |
| strategy_pivot_recency_bars | 20 | >0 | Maximum age of the newest pivot. |
| strategy_entry_atr_buffer | 0.50 | >=0 | ATR offset for buy-stop and sell-stop trigger levels. |
| strategy_sl_atr_buffer | 0.50 | >=0 | ATR buffer beyond the opposite pattern extreme for the initial stop. |
| strategy_sl_atr_cap | 4.00 | >0 | Maximum initial stop distance in ATR units. |
| strategy_tp_measured_move | 0.65 | >0 | Pattern amplitude fraction used for take profit. |
| strategy_partial_move_scale | 0.50 | >0 | Pattern amplitude fraction used for partial close and failure depth. |
| strategy_partial_close_fraction | 0.50 | 0-1 | Fraction of open volume to close at the partial trigger. |
| strategy_order_valid_bars | 8 | >0 | Pending stop validity in H4 bars. |
| strategy_time_stop_bars | 35 | >0 | Maximum holding period in H4 bars. |
| strategy_failure_exit_bars | 5 | >0 | Bars after entry during which a deep return closes the trade. |
| strategy_reuse_guard_bars | 30 | >=0 | Cooldown after entry, exit, or invalidation. |
| strategy_spread_atr_max | 0.20 | >=0 | Maximum allowed modeled spread as a fraction of H4 ATR for new entries. |
| strategy_d1_atr_median_bars | 60 | >0 | D1 ATR sample length for volatility regime median. |
| strategy_d1_atr_ratio_min | 0.80 | >0 | Lower allowed current D1 ATR to median D1 ATR ratio. |
| strategy_d1_atr_ratio_max | 2.00 | >min | Upper allowed current D1 ATR to median D1 ATR ratio. |
| strategy_news_blackout_h4_bars | 2 | >=0 | High-impact news blackout in H4 bars before and after event time. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major with native DWX H4 OHLC.
- GBPUSD.DWX - liquid FX major with native DWX H4 OHLC.
- USDJPY.DWX - liquid FX major with native DWX H4 OHLC.
- AUDUSD.DWX - liquid FX major with native DWX H4 OHLC.
- USDCAD.DWX - liquid FX major with native DWX H4 OHLC.
- USDCHF.DWX - liquid FX major with native DWX H4 OHLC.
- NZDUSD.DWX - liquid FX major with native DWX H4 OHLC.
- XAUUSD.DWX - native DWX gold CFD named by the card.
- NDX.DWX - native DWX Nasdaq 100 index CFD named by the card.
- WS30.DWX - native DWX Dow 30 index CFD named by the card.
- GDAXI.DWX - native DWX DAX 40 index CFD named by the card.
- UK100.DWX - native DWX FTSE 100 index CFD named by the card.
- XTIUSD.DWX - native DWX oil CFD named by the card.

**Explicitly NOT for:**
- SP500.DWX - not listed in the card's R3 portable basket for this strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 ATR median volatility-regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | 8 to 35 H4 bars |
| Expected drawdown profile | Breakout-reversal trades with ATR-capped pattern stops. |
| Regime preference | Volatility-expansion reversal after broadening structure. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum cluster with book references
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1422_classical-broadening-formation-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1422_classical-broadening-formation-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | 602048e0-1237-4757-8128-72b4aeb8eb1f |
