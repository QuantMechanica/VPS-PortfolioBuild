# QM5_10100_mql5-ga-fractal - Strategy Spec

**EA ID:** QM5_10100
**Slug:** `mql5-ga-fractal`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `sources/mql5-examples`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA finds the three most recent alternating opposing fractals and treats the bars between the newest and oldest of those fractals as a candidate consolidation range. The range must have a minimum duration, enough ATR-proportional height, and touches near both the upper and lower side zones. It scores the final leg against the prior leg using length, slope, and time ratios; if enough votes agree, the final leg sets the breakout bias. A long opens after a closed-bar break above the range high plus an ATR buffer, and a short opens after a closed-bar break below the range low minus an ATR buffer; exits are by stop, target, framework Friday close, or a close back inside the stored breakout range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fractal_lookback_bars` | 120 | 10-500 | Closed bars scanned for the three alternating fractals. |
| `strategy_min_range_bars` | 12 | 3-200 | Minimum duration between newest and oldest qualifying fractal. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for range height, breakout buffer, and stop buffer. |
| `strategy_min_range_atr_mult` | 0.75 | 0.10-10.00 | Minimum range height as a multiple of ATR. |
| `strategy_side_zone_fraction` | 0.15 | 0.01-0.50 | Distance from each range edge counted as a side-zone touch. |
| `strategy_min_side_touches` | 2 | 1-20 | Minimum total side-zone touches, with at least one touch per side. |
| `strategy_length_ratio_min` | 1.15 | 0.50-5.00 | Final leg length ratio vote threshold. |
| `strategy_slope_ratio_min` | 1.15 | 0.50-5.00 | Final leg slope ratio vote threshold. |
| `strategy_time_ratio_max` | 0.85 | 0.10-2.00 | Final leg time ratio vote threshold. |
| `strategy_vote_threshold` | 2 | 1-3 | Minimum geometry votes required for a directional bias. |
| `strategy_breakout_atr_buffer` | 0.10 | 0.00-5.00 | ATR buffer beyond the range boundary for breakout confirmation. |
| `strategy_sl_atr_buffer` | 0.25 | 0.00-5.00 | ATR buffer outside the selected structure stop. |
| `strategy_take_profit_rr` | 2.00 | 0.25-10.00 | Fixed R multiple used when measured-move TP is disabled. |
| `strategy_use_measured_move_tp` | false | true/false | If true, use one range-height measured move instead of fixed 2R. |
| `strategy_use_last_swing_stop` | true | true/false | If true, stop is based on the latest internal opposing fractal; otherwise range edge. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX target with native DWX data.
- `XAUUSD.DWX` - card-listed gold target with native DWX data.
- `NDX.DWX` - card-listed Nasdaq 100 index target with native DWX data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered or broker-data validated for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | intraday to multi-session breakout holds |
| Expected drawdown profile | clustered losses during false-breakout or range-expansion whipsaws |
| Regime preference | volatility-expansion breakout after fractal consolidation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** `MQL5 article`
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 59): Using Geometric Asymmetry to Identify Precision Breakouts from Fractal Consolidation", MQL5 Articles, https://www.mql5.com/en/articles/21197
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10100_mql5-ga-fractal.md`

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
| v1 | 2026-06-12 | Initial build from card | b96b536b-68e5-40f2-b3f8-9df389a21a97 |
