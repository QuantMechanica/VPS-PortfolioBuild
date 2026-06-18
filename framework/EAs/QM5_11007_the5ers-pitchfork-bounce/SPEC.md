# QM5_11007_the5ers-pitchfork-bounce - Strategy Spec

**EA ID:** QM5_11007
**Slug:** the5ers-pitchfork-bounce
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see approved card source)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades H4 Andrews Pitchfork outer-line bounces. It confirms swing anchors with a 3-left/3-right fractal rule, builds the latest bullish low-high-higher-low or bearish high-low-lower-high pitchfork, and enters after a closed candle touches and rejects the relevant outer parallel with RSI confirmation. Long trades target the median line from a lower-line bounce; short trades target the median line from an upper-line bounce. Entries are skipped if the median-line target is less than 1R away, and the target is capped at 2.5R.

Exits occur through SL/TP, a close beyond the touched outer line by 0.25 ATR, the 24 H4-bar time stop, and the framework Friday/news/kill-switch exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_swing_width | 3 | 2-5 | Left/right bars used to confirm pitchfork swing anchors. |
| strategy_atr_period | 14 | 5-50 | ATR period for touch tolerance, pitchfork spacing, and stop buffer. |
| strategy_touch_atr_mult | 0.25 | 0.15-0.40 | Maximum ATR distance from the touched pitchfork outer line. |
| strategy_reject_wick_ratio | 0.50 | 0.25-0.75 | Minimum rejected wick share of the signal candle range. |
| strategy_rsi_long_max | 35.0 | 20.0-45.0 | Maximum RSI(14) allowed for long bounce entries. |
| strategy_rsi_short_min | 65.0 | 55.0-80.0 | Minimum RSI(14) allowed for short bounce entries. |
| strategy_stop_atr_mult | 0.50 | 0.25-1.50 | ATR buffer beyond the touched candle high/low for SL placement. |
| strategy_min_spacing_atr | 2.0 | 1.0-5.0 | Minimum distance between pitchfork outer lines in ATR units. |
| strategy_min_target_rr | 1.0 | 0.5-2.0 | Minimum median-line target distance in R units. |
| strategy_max_target_rr | 2.5 | 1.0-5.0 | Maximum target distance in R units. |
| strategy_min_a_bars | 30 | 10-80 | Minimum bars between pitchfork point A and entry. |
| strategy_pitchfork_expiry | 120 | 40-240 | Maximum H4 bars since point C before a pitchfork expires. |
| strategy_time_stop_bars | 24 | 6-60 | Maximum holding time in H4 bars. |
| strategy_scan_bars | 180 | 80-400 | Bounded swing scan depth. |
| strategy_max_spread_points | 0 | 0-500 | Optional wide-spread block; 0 disables the strategy spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair with H4 OHLC, RSI, and ATR available.
- GBPUSD.DWX - liquid major FX pair with H4 OHLC, RSI, and ATR available.
- AUDUSD.DWX - liquid major FX pair with H4 OHLC, RSI, and ATR available.
- EURJPY.DWX - liquid FX cross with H4 OHLC, RSI, and ATR available.
- XAUUSD.DWX - liquid metal CFD where channel support/resistance bounces are structurally portable.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available in the DWX tester universe.
- Non-FX/non-metal symbols - not part of the approved card target universe for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Up to 24 H4 bars, roughly four trading days. |
| Expected drawdown profile | Moderate mean-reversion drawdown during directional breakouts through the pitchfork line. |
| Regime preference | Mean-reversion/channel support-resistance bounces. |
| Win rate target (qualitative) | Medium |

Expected trade frequency from the card: H4 Andrews pitchfork outer-line bounces are selective but recurring across liquid FX/metals; conservative estimate 12-30 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11007_the5ers-pitchfork-bounce.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11007_the5ers-pitchfork-bounce.md`

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
| v1 | 2026-06-18 | Initial build from card | 2988a363-6fa3-44d7-abe5-7fd4f5f86ad1 |
