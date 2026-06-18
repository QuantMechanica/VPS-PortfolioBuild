# QM5_11006_the5ers-trendline-rsi - Strategy Spec

**EA ID:** QM5_11006
**Slug:** the5ers-trendline-rsi
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H4 trendline breakout-retest setups confirmed by RSI. It builds an ascending line from the two most recent confirmed swing lows for short setups and a descending line from the two most recent confirmed swing highs for long setups. A short opens after a close breaks below the ascending line within the retest window, the current closed bar retests and rejects the underside, and RSI(14) is below 40. A long uses the mirrored rule above a descending line with RSI(14) above 60; exits are the 2.0R target, initial ATR-buffered stop, a close back across the broken line, or a 30-bar H4 time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 14 | 2-100 | RSI period used for momentum confirmation. |
| strategy_rsi_long_min | 60.0 | 0-100 | Long entries require RSI above this level. |
| strategy_rsi_short_max | 40.0 | 0-100 | Short entries require RSI below this level. |
| strategy_atr_period | 14 | 2-100 | ATR period used for break, retest, slope, and stop buffers. |
| strategy_pivot_left | 2 | 1-10 | Older-side bars required to confirm a swing pivot. |
| strategy_pivot_right | 2 | 1-10 | Newer-side closed bars required before a swing pivot is usable. |
| strategy_scan_lookback | 80 | 20-300 | Maximum closed bars scanned for the two trendline anchors. |
| strategy_retest_window | 6 | 1-30 | Closed-bar lookback in which the line break must have occurred. |
| strategy_break_atr_mult | 0.25 | 0.0-5.0 | Minimum breakout depth as a multiple of ATR. |
| strategy_retest_atr_mult | 0.25 | 0.0-5.0 | Retest proximity tolerance as a multiple of ATR. |
| strategy_slope_atr_mult | 0.05 | 0.0-5.0 | Minimum absolute trendline slope per bar as a multiple of ATR. |
| strategy_min_anchor_bars | 20 | 2-300 | Minimum bars between the older anchor and entry. |
| strategy_sl_atr_mult | 0.5 | 0.0-10.0 | Stop buffer beyond the retest candle as a multiple of ATR. |
| strategy_tp_rr | 2.0 | 0.1-10.0 | Take-profit distance as an R multiple. |
| strategy_time_stop_bars | 30 | 1-300 | Maximum hold in H4 bars before strategy exit. |
| strategy_spread_pct_of_stop | 15.0 | 0.0-100.0 | Blocks only genuinely wide positive spread relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major with H4 OHLC, RSI, and ATR data.
- GBPUSD.DWX - card-listed liquid FX major with H4 OHLC, RSI, and ATR data.
- USDJPY.DWX - card-listed liquid FX major with H4 OHLC, RSI, and ATR data.
- XAUUSD.DWX - card-listed metal CFD with H4 OHLC, RSI, and ATR data.
- GDAXI.DWX - canonical DWX DAX symbol in the matrix; used for the card's GER40.DWX exposure.

**Explicitly NOT for:**
- GER40.DWX - card-stated alias is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered canonical substitute.
- SPX500.DWX - not a canonical DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Several H4 bars up to 30 H4 bars |
| Expected drawdown profile | Trend breakout strategy with clustered losses in choppy ranges. |
| Regime preference | breakout / trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** article
**Pointer:** https://the5ers.com/market-trends-strategies/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11006_the5ers-trendline-rsi.md`

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
| v1 | 2026-06-18 | Initial build from card | f62aa5bc-b501-449d-8642-3b7101263ca2 |
