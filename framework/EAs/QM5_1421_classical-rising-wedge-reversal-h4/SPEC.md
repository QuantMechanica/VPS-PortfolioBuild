# QM5_1421_classical-rising-wedge-reversal-h4 - Strategy Spec

**EA ID:** QM5_1421
**Slug:** classical-rising-wedge-reversal-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA trades bearish reversals after an H4 rising-wedge pattern. It first requires an H4 prior uptrend, then finds a 30-100 bar window where Williams 5-bar pivot highs and lows define two upward-sloping trendlines with the lower line rising faster than the upper line. When the wedge is active, contracting, not previously broken, and the D1 SMA(50) is flat or falling, it places a SELL STOP below the lower trendline by 0.5 ATR(14). The initial stop is above the upper trendline plus 0.4 ATR(14), capped at 3 ATR(14), and the take-profit is 0.75 of wedge height below entry.

Open trades partially close 50% halfway to target and move the stop to entry. The EA closes early if the pattern fails in the first 5 H4 bars or if the trade remains open for 30 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | >0 | ATR period for H4 buffers and D1 macro slope scaling. |
| strategy_prior_lookback_bars | 60 | >0 | H4 bars used for the prior uptrend regression and rally range. |
| strategy_wedge_min_bars | 30 | >=30 | Minimum H4 bars in the wedge window. |
| strategy_wedge_max_bars | 100 | 30-120 | Maximum H4 bars in the wedge window. |
| strategy_pivot_wing | 2 | fixed 2 | Williams 5-bar fractal wing length. |
| strategy_min_pivots | 3 | >=3 | Minimum pivot highs and lows required for each trendline. |
| strategy_prior_slope_atr_per_bar | 0.15 | >=0 | Required prior-trend slope in ATR units per H4 bar. |
| strategy_prior_rally_atr_mult | 5.0 | >0 | Required prior 60-bar high-low rally range in ATR units. |
| strategy_slope_ratio_min | 1.30 | >1 | Minimum lower/upper trendline slope ratio. |
| strategy_slope_ratio_max | 4.00 | >min | Maximum lower/upper trendline slope ratio. |
| strategy_apex_min_frac | 0.15 | 0-1 | Minimum projected apex distance as a fraction of wedge length. |
| strategy_apex_max_frac | 0.70 | 0-1 | Maximum projected apex distance as a fraction of wedge length. |
| strategy_range_contraction_min | 1.50 | >1 | Minimum first-10-bars range divided by last-10-bars range. |
| strategy_pivot_span_frac | 0.50 | 0-1 | Minimum pivot span fraction of the wedge window. |
| strategy_entry_atr_buffer | 0.50 | >=0 | ATR buffer below lower trendline for the SELL STOP. |
| strategy_sl_atr_buffer | 0.40 | >=0 | ATR buffer above upper trendline for the initial stop. |
| strategy_max_sl_atr_mult | 3.00 | >0 | Hard cap on initial stop distance in ATR units. |
| strategy_tp_height_mult | 0.75 | >0 | Measured-move target as a fraction of wedge height. |
| strategy_partial_progress | 0.50 | 0-1 | Fraction of target distance that triggers partial close. |
| strategy_partial_fraction | 0.50 | 0-1 | Fraction of position volume to close at the partial trigger. |
| strategy_failure_bars | 5 | >=0 | H4 bars after entry during which pattern-failure close is active. |
| strategy_time_stop_bars | 30 | >0 | Maximum H4 bars to hold a position. |
| strategy_pending_valid_bars | 10 | >0 | Expiration horizon for the SELL STOP in H4 bars. |
| strategy_reuse_guard_bars | 20 | >=0 | H4 bars to suppress immediate redetection after placing a pattern order. |
| strategy_spread_atr_frac | 0.20 | >=0 | Entry spread cap as a fraction of ATR(14,H4). |
| strategy_macro_sma_period | 50 | >0 | D1 SMA period for the macro-bias gate. |
| strategy_macro_slope_bars | 20 | >0 | D1 bars used to measure SMA slope. |
| strategy_macro_slope_atr_per_bar | 0.05 | >=0 | Maximum allowed D1 SMA slope in ATR units per D1 bar. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with native H4 OHLC coverage.
- GBPUSD.DWX - FX major with native H4 OHLC coverage.
- USDJPY.DWX - FX major with native H4 OHLC coverage.
- USDCHF.DWX - FX major with native H4 OHLC coverage.
- USDCAD.DWX - FX major with native H4 OHLC coverage.
- AUDUSD.DWX - FX major with native H4 OHLC coverage.
- NZDUSD.DWX - FX major with native H4 OHLC coverage.
- XAUUSD.DWX - Gold CFD named in the card's portable R3 universe.
- XTIUSD.DWX - Oil CFD named in the card's portable R3 universe.
- NDX.DWX - Nasdaq 100 index CFD named in the card's portable R3 universe.
- WS30.DWX - Dow 30 index CFD named in the card's portable R3 universe.
- GDAXI.DWX - DAX 40 index CFD named in the card's portable R3 universe.
- UK100.DWX - FTSE 100 index CFD named in the card's portable R3 universe.

**Explicitly NOT for:**
- SP500.DWX - Not named by this card's R3 universe.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols in the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(50), D1 ATR(14) for macro-bias slope gate |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 30 H4 bars; partial management may occur earlier |
| Expected drawdown profile | Reversal breakout profile with risk capped by initial stop no wider than 3 ATR |
| Regime preference | H4 bearish reversal after prior uptrend and volatility contraction |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book and forum implementation cluster
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1421_classical-rising-wedge-reversal-h4.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1421_classical-rising-wedge-reversal-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | d59c4657-6b72-4547-80c6-2890a8881ed1 |
