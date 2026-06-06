# QM5_10965_ftmo-morn-star - Strategy Spec

**EA ID:** QM5_10965
**Slug:** ftmo-morn-star
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades long H4 Morning Star reversals after a downtrend. It requires SMA(50) below SMA(100), lower swing lows and lower swing highs, and a three-candle Morning Star forming near prior swing-low support or a round-number level. A market buy is opened only when a later closed H4 candle breaks above the Morning Star candle-three high within three bars. The stop is below the pattern low by 0.25 ATR(14), the default target is 2.0R, and the EA moves the stop to breakeven after price reaches 1.0R or exits after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 1+ | H4 ATR period for candle size, support tolerance, and stop buffer. |
| strategy_sma_fast_period | 50 | 1+ | Fast H4 SMA used in the downtrend filter. |
| strategy_sma_slow_period | 100 | 1+ | Slow H4 SMA used in the downtrend filter. |
| strategy_swing_lookback_bars | 40 | 10+ | H4 window used to confirm lower swing lows and highs. |
| strategy_support_lookback_bars | 60 | 10+ | H4 window used to find prior swing-low support and alternate target swing highs. |
| strategy_entry_window_bars | 3 | 1+ | Maximum closed H4 bars after candle three allowed for breakout entry. |
| strategy_max_hold_bars | 20 | 1+ | Time exit in H4 bars. |
| strategy_slope_positive_max_bars | 10 | 0+ | Blocks late reversals when SMA(50) has risen for more than this many H4 bars. |
| strategy_round_step_points | 1000 | 1+ | Point step used to detect round-number support. |
| strategy_candle1_body_atr_mult | 0.80 | 0+ | Minimum candle-one real body as a multiple of ATR(14). |
| strategy_candle2_body_ratio | 0.35 | 0+ | Maximum candle-two body as a fraction of candle-one body. |
| strategy_support_atr_mult | 0.35 | 0+ | Support proximity threshold as a multiple of ATR(14). |
| strategy_round_tolerance_pct | 0.15 | 0+ | Maximum distance from nearest round number as a percent of price. |
| strategy_sl_atr_buffer_mult | 0.25 | 0+ | Stop buffer below the three-candle pattern low. |
| strategy_min_stop_atr_mult | 0.50 | 0+ | Minimum accepted stop distance as ATR multiple. |
| strategy_max_stop_atr_mult | 2.50 | 0+ | Maximum accepted stop distance as ATR multiple. |
| strategy_primary_rr | 2.00 | 0+ | Default take-profit distance in R. |
| strategy_alt_tp_min_rr | 1.50 | 0+ | Minimum R for replacing default TP with prior swing high. |
| strategy_alt_tp_max_rr | 3.00 | 0+ | Maximum R for replacing default TP with prior swing high. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major from the card's R3 basket.
- USDJPY.DWX - liquid FX major from the card's R3 basket.
- GBPUSD.DWX - liquid FX major from the card's R3 basket.
- XAUUSD.DWX - liquid gold market from the card's R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest artifacts must use canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - no broker/custom-symbol evidence for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | Up to 20 H4 bars, approximately 80 trading hours. |
| Expected drawdown profile | Selective reversal entries with fixed initial risk and 2.0R primary target. |
| Regime preference | Downtrend exhaustion into support followed by bullish reversal. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, "Trading strategy using the Morning Star Pattern", 2025-03-21.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10965_ftmo-morn-star.md`

Implementation note: the card says "round-number level" but does not define the increment. The EA exposes `strategy_round_step_points` and defaults it to 1000 points, which maps to common FX and XAU round levels under DWX point sizes.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 0edd1dde-0ee3-4431-ba03-3a485b8458d9 |
