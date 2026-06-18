# QM5_11008_the5ers-hs-neckline - Strategy Spec

**EA ID:** QM5_11008
**Slug:** the5ers-hs-neckline
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades H4 head-and-shoulders and inverse head-and-shoulders reversals after the full pattern is confirmed. It detects 3-left/3-right swing points, requires a prior EMA(100) trend, validates shoulder/head geometry with ATR tolerances, and enters only after the last closed H4 bar breaks the projected neckline by at least 0.25 ATR. Stops are placed beyond the right shoulder with a 0.5 ATR buffer, take profit is 2.0R, and positions close if price closes back across the neckline or after 30 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_pivot_left | 3 | 1-10 | Bars to the left required to confirm a swing high or low. |
| strategy_pivot_right | 3 | 1-10 | Bars to the right required to confirm a swing high or low. |
| strategy_ema_period | 100 | 20-300 | EMA period used for the prior-trend filter. |
| strategy_trend_lookback | 30 | 20-80 | Bars inspected for the prior-trend filter. |
| strategy_trend_min_count | 20 | 10-80 | Minimum bars in the prior-trend window that must be above or below EMA. |
| strategy_atr_period | 14 | 5-50 | ATR period used for pattern tolerances and stop buffer. |
| strategy_head_atr_mult | 0.75 | 0.25-3.0 | Minimum ATR distance by which the head must exceed both shoulders. |
| strategy_shoulder_atr_mult | 1.0 | 0.25-3.0 | Maximum ATR distance allowed between left and right shoulder heights. |
| strategy_break_atr_mult | 0.25 | 0.05-1.0 | Required neckline-break distance in ATR units. |
| strategy_slope_atr_mult | 0.20 | 0.05-1.0 | Maximum allowed neckline slope per bar in ATR units. |
| strategy_span_min | 20 | 5-120 | Minimum bars from left shoulder to right shoulder. |
| strategy_span_max | 120 | 20-240 | Maximum bars from left shoulder to right shoulder. |
| strategy_sl_atr_mult | 0.5 | 0.1-2.0 | Stop buffer beyond the right-shoulder swing extreme. |
| strategy_take_rr | 2.0 | 0.5-5.0 | Take-profit multiple of initial risk. |
| strategy_time_stop_bars | 30 | 5-120 | Maximum holding time in H4 bars. |
| strategy_scan_lookback | 160 | 80-300 | Closed-bar history depth used for bounded pivot scanning. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with deep H4 OHLC history and structurally clean swing patterns.
- GBPUSD.DWX - FX major with DWX H4 OHLC, EMA, and ATR availability.
- USDJPY.DWX - FX major with DWX H4 OHLC, EMA, and ATR availability.
- XAUUSD.DWX - Liquid metal CFD with swing-reversal structure and DWX H4 history.
- GDAXI.DWX - DWX DAX custom symbol used as the available replacement for card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - Card-stated symbol is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 30 H4 bars by strategy time stop |
| Expected drawdown profile | Structural reversal strategy with ATR-defined loss per trade |
| Regime preference | Trend reversal after neckline breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/five-powerful-reversal-patterns-every-trader-must-know/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11008_the5ers-hs-neckline.md`

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
| v1 | 2026-06-18 | Initial build from card | 263433da-a0b9-4f03-9bb4-efccd6679b2b |
