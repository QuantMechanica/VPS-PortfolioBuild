# QM5_10970_ftmo-dbl-neck - Strategy Spec

**EA ID:** QM5_10970
**Slug:** `ftmo-dbl-neck`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see FTMO Australia blog source)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades closed H4 double top and double bottom neckline reversals. A short setup requires an uptrend state, two swing highs 5-30 H4 bars apart, matching peaks within 0.5 ATR, and an intervening valley at least 1 ATR below the lower peak; it enters when the last closed H4 candle closes below the valley neckline. A long setup mirrors this logic after a downtrend, with two swing lows and a breakout close above the intervening peak neckline. The stop is placed beyond the two pattern extremes by 0.25 ATR, take profit projects the pattern height from the neckline capped at 3R, breakeven is applied after 1R, and any remaining trade exits after 40 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 100 | 20-300 | EMA period for the trend-state filter. |
| `strategy_slope_bars` | 20 | 5-60 | Closed-bar lookback for positive or negative trend slope. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for pattern tolerance, depth, stop buffer, and breakout range filter. |
| `strategy_lookback_bars` | 60 | 40-120 | Closed H4 bars scanned for swing structure. |
| `strategy_swing_strength` | 2 | 1-5 | Bars on each side required to qualify a swing pivot. |
| `strategy_min_sep_bars` | 5 | 3-15 | Minimum separation between the two peaks or troughs. |
| `strategy_max_sep_bars` | 30 | 10-60 | Maximum separation between the two peaks or troughs. |
| `strategy_peak_tol_atr` | 0.5 | 0.1-2.0 | Maximum ATR-scaled distance between the two peaks or troughs. |
| `strategy_valley_min_atr` | 1.0 | 0.5-4.0 | Minimum ATR-scaled neckline depth from the paired extremes. |
| `strategy_height_min_atr` | 1.0 | 0.5-4.0 | Minimum ATR-scaled pattern height. |
| `strategy_height_max_atr` | 6.0 | 2.0-12.0 | Maximum ATR-scaled pattern height. |
| `strategy_sl_buffer_atr` | 0.25 | 0.0-2.0 | ATR buffer beyond the two pattern extremes for stop placement. |
| `strategy_breakout_max_atr` | 2.5 | 0.5-8.0 | Maximum ATR-scaled range of the breakout candle. |
| `strategy_tp_rr_cap` | 3.0 | 1.0-5.0 | Maximum reward multiple allowed for projected-height target. |
| `strategy_tp_rr_fallback` | 2.0 | 1.0-4.0 | Fallback reward multiple if the projected target is invalid. |
| `strategy_time_exit_bars` | 40 | 5-100 | Maximum H4 bars to hold before time exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with H4 DWX history.
- `GBPUSD.DWX` - card-listed liquid FX major with H4 DWX history.
- `USDJPY.DWX` - card-listed liquid FX major with H4 DWX history.
- `XAUUSD.DWX` - card-listed liquid metal symbol with H4 DWX history.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not available for DWX tester routing.
- Symbols not listed in the approved card's R3 basket - no card approval for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | Up to 40 H4 bars, derived from the card's time-exit rule. |
| Expected drawdown profile | Selective neckline reversal trades with ATR-defined stops; drawdown expected to cluster during failed reversals in persistent trends. |
| Regime preference | Reversal after mature trend state with neckline breakout confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://ftmo.com/au/how-to-trade-chart-patterns/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10970_ftmo-dbl-neck.md`

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
| v1 | 2026-06-18 | Initial build from card | 3d57d4ee-08d5-43c8-936d-8bf7919d71e7 |
