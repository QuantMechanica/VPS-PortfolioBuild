# QM5_10099_mql5-trend3 - Strategy Spec

**EA ID:** QM5_10099
**Slug:** `mql5-trend3`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA finds swing highs and swing lows on closed H1 bars using a fixed lookback on both sides of each candidate pivot. It validates the most recent three swing highs as a resistance trendline and the most recent three swing lows as a support trendline when the middle swing sits within an ATR-based tolerance of the line. It buys when the last closed bar breaks above the resistance line by an ATR buffer, and sells when the last closed bar breaks below the support line by the same style of buffer. Stops are placed beyond the most recent opposing swing with an ATR buffer, targets are fixed at 2R, and an opposite validated breakout triggers a strategy exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_lookback` | 3 | 1-20 | Bars required on each side of a swing pivot. |
| `strategy_scan_bars` | 160 | 30-500 | Closed-bar history window scanned for swing structures. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for buffers and optional swing-size filtering. |
| `strategy_min_swing_atr_mult` | 0.0 | 0.0-5.0 | Optional minimum swing size as an ATR multiple; 0 disables it. |
| `strategy_line_tolerance_atr_mult` | 0.25 | 0.0-2.0 | Maximum middle-swing deviation from the candidate trendline. |
| `strategy_breakout_atr_mult` | 0.10 | 0.0-3.0 | ATR buffer required beyond the trendline for breakout confirmation. |
| `strategy_sl_atr_buffer_mult` | 0.50 | 0.0-5.0 | ATR buffer beyond the most recent opposing swing for stop placement. |
| `strategy_tp_r_multiple` | 2.0 | 0.5-10.0 | Take-profit distance as a multiple of initial risk. |
| `strategy_breakout_use_close` | true | true/false | Use close-based breakout when true; otherwise use high/low breakouts. |
| `strategy_max_spread_points` | 0.0 | 0.0-10000.0 | Optional spread cap; 0 disables the extra cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX OHLC and ATR data.
- `GBPJPY.DWX` - card-listed liquid FX cross with DWX OHLC and ATR data.
- `GDAXI.DWX` - card-listed index CFD with DWX OHLC and ATR data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.
- Non-OHLC synthetic inputs - the strategy requires native bar highs, lows, closes, and ATR.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Not specified by card; positions exit by SL, 2R TP, opposite breakout, or Friday close. |
| Expected drawdown profile | Not specified by card; structural breakout with fixed initial risk. |
| Regime preference | Trendline breakout / volatility expansion. |
| Win rate target (qualitative) | Not specified by card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** MQL5 article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 61): Structural Slanted Trendline Breakouts with 3-Swing Validation", MQL5 Articles, 2026.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10099_mql5-trend3.md`

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
| v1 | 2026-06-12 | Initial build from card | b1ed90ed-2714-4259-abe0-61d59162ebb2 |
