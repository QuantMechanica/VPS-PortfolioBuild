# QM5_1418_classical-falling-wedge-reversal-h4 - Strategy Spec

**EA ID:** QM5_1418
**Slug:** classical-falling-wedge-reversal-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `artifacts/cards_approved/QM5_1418_classical-falling-wedge-reversal-h4.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades bullish falling-wedge reversals on H4. On each closed H4 bar it requires a prior 60-bar downtrend, then searches for a 30-100 bar wedge whose pivot-high and pivot-low regressions both slope downward, with the upper line falling faster than the lower line. If range contraction, apex-distance, no-prior-break, pivot-variety, D1 SMA(50) slope, spread, and news filters pass, it places a BUY_STOP at the projected upper trendline plus 0.5 ATR(14).

The initial stop is the projected lower trendline minus 0.4 ATR(14), capped to no worse than 3.0 ATR from entry. The take-profit is entry plus 0.75 of the wedge height. The EA partial-closes 50% after 0.50 of the measured move, moves SL to entry, exits on pattern failure during the first 5 H4 bars, and time-stops after 30 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period for buffers, stop cap, spread scaling, and macro slope threshold. |
| `strategy_wedge_min_bars` | 30 | 30-100 | Minimum H4 bars in the wedge window. |
| `strategy_wedge_max_bars` | 100 | 30-120 | Maximum H4 bars scanned for an active wedge. |
| `strategy_prior_trend_bars` | 60 | 20-120 | Prior downtrend regression and drawdown window before the wedge. |
| `strategy_pivot_span` | 2 | fixed 2 | Williams 5-bar fractal span. |
| `strategy_prior_slope_atr_per_bar_max` | -0.15 | negative | Maximum prior-trend slope, in ATR per bar. |
| `strategy_prior_drawdown_atr_min` | 5.0 | 1.0-20.0 | Minimum prior-trend high-low drawdown in ATR units. |
| `strategy_slope_ratio_min` | 1.30 | 1.0-4.0 | Minimum upper/lower downward slope ratio. |
| `strategy_slope_ratio_max` | 4.00 | 1.3-8.0 | Maximum upper/lower downward slope ratio. |
| `strategy_apex_distance_min` | 0.15 | 0.0-1.0 | Minimum projected apex distance as a fraction of wedge length. |
| `strategy_apex_distance_max` | 0.70 | 0.0-2.0 | Maximum projected apex distance as a fraction of wedge length. |
| `strategy_range_contraction_min` | 1.50 | 1.0-5.0 | Required ratio of first-10-bar range to last-10-bar range. |
| `strategy_pivot_variety_min` | 0.50 | 0.0-1.0 | Minimum pivot span coverage as a fraction of wedge length. |
| `strategy_entry_atr_buffer` | 0.50 | 0.0-2.0 | ATR buffer added to projected upper trendline for BUY_STOP. |
| `strategy_sl_atr_buffer` | 0.40 | 0.0-2.0 | ATR buffer below projected lower trendline for initial SL. |
| `strategy_sl_atr_cap` | 3.00 | 0.5-10.0 | Worst-case stop distance cap in ATR units. |
| `strategy_tp_height_fraction` | 0.75 | 0.1-2.0 | Fraction of wedge height used for measured-move TP. |
| `strategy_partial_height_fraction` | 0.50 | 0.1-1.0 | Fraction of wedge height that triggers partial close. |
| `strategy_partial_close_fraction` | 0.50 | 0.1-0.9 | Fraction of open volume closed at partial target. |
| `strategy_order_valid_bars` | 10 | 1-30 | H4 bars before an unfilled BUY_STOP expires. |
| `strategy_time_stop_bars` | 30 | 1-100 | H4 bars after entry before hard time-stop. |
| `strategy_failure_exit_bars` | 5 | 1-20 | H4 bars after entry where close back below breakout line forces exit. |
| `strategy_reuse_guard_bars` | 20 | 0-100 | H4 bars to suppress re-detection after a position closes. |
| `strategy_spread_atr_max` | 0.20 | 0.0-1.0 | Maximum modeled spread as a fraction of H4 ATR. |
| `strategy_macro_sma_period` | 50 | 20-200 | D1 SMA period for the macro-bias filter. |
| `strategy_macro_slope_bars` | 20 | 5-80 | D1 bars used to measure SMA slope. |
| `strategy_macro_min_slope_atr` | -0.05 | negative to positive | Minimum D1 SMA slope in D1 ATR per bar. |
| `strategy_news_blackout_enabled` | true | true/false | Enables the card's high-impact news blackout hook. |
| `strategy_news_blackout_h4_bars` | 2 | 0-6 | H4 bars before and after news to suppress trading. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `GBPUSD.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `USDJPY.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `AUDUSD.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `USDCAD.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `USDCHF.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `NZDUSD.DWX` - standard DWX FX major; H4 OHLC supports wedge geometry.
- `XAUUSD.DWX` - card-listed metal CFD with native DWX H4 data.
- `NDX.DWX` - card-listed US index CFD with native DWX H4 data.
- `WS30.DWX` - card-listed US index CFD with native DWX H4 data.
- `GDAXI.DWX` - card-listed DAX index CFD with native DWX H4 data.
- `UK100.DWX` - card-listed FTSE index CFD with native DWX H4 data.
- `XTIUSD.DWX` - card-listed oil CFD with native DWX H4 data.

**Explicitly NOT for:**
- `SP500.DWX` - available in the matrix, but not listed in this card's R3 symbol basket.
- Non-DWX symbols - framework and pipeline tests require `.DWX` research/backtest symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(50) slope over 20 D1 bars and D1 ATR(14) macro-bias threshold |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 30 H4 bars, usually several days to a few weeks |
| Expected drawdown profile | Reversal-breakout profile with false-break losses capped by ATR and structure stop |
| Regime preference | Bullish reversal after a downtrend, with D1 trend flat or rising enough to avoid catastrophic macro trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book plus forum implementation cluster
**Pointer:** Edwards & Magee, *Technical Analysis of Stock Trends*, 10th edition, ch. 10, Falling Wedges, plus ForexFactory falling-wedge EA implementation cluster
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1418_classical-falling-wedge-reversal-h4.md`

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
| v1 | 2026-06-30 | Initial build from card | 74b41290-dd51-489d-aad5-ce720130f5be |
