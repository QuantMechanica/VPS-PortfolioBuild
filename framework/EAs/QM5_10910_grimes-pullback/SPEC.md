# QM5_10910_grimes-pullback - Strategy Spec

**EA ID:** QM5_10910
**Slug:** grimes-pullback
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades a continuation pullback on H1 bars. A long setup requires EMA(50) rising, the last closed bar above EMA(50), a recent strong thrust above the prior 20-bar high, a pullback back into an EMA(20) ATR band without closing below EMA(50), and a trigger close above the prior bar high. Shorts mirror the same rules below EMA(50), with a thrust below the prior 20-bar low and a trigger close below the prior bar low. The stop is placed beyond the pullback swing with an ATR buffer, the target is 1.5R, positions move to breakeven after 1R, then trail by 2 ATR (the stop ratchets from the current market price by 2*ATR, only ever tightening, approximating the card's "trail from highest/lowest close since entry"), and time out after 16 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_trend_period | 50 | 2-200 | EMA period used for trend direction and close-above or close-below validation. |
| strategy_ema_pullback_period | 20 | 2-100 | EMA period used as the pullback reference. |
| strategy_atr_period | 14 | 2-100 | ATR period used for thrust body, pullback band, stop filter, and trailing. |
| strategy_thrust_lookback_bars | 12 | 1-50 | Number of recent bars searched for the thrust event. |
| strategy_breakout_lookback_bars | 20 | 2-100 | Prior range length used to define thrust breakout highs and lows. |
| strategy_thrust_body_atr_mult | 1.0 | 0.1-5.0 | Minimum thrust-bar body as a multiple of ATR. |
| strategy_pullback_atr_band | 0.25 | 0.0-2.0 | Distance around EMA(20) that qualifies as a pullback touch. |
| strategy_stop_buffer_atr_mult | 0.20 | 0.0-2.0 | ATR buffer beyond pullback swing low or high for the stop. |
| strategy_min_stop_atr_mult | 0.60 | 0.1-5.0 | Minimum accepted stop distance as ATR multiple. |
| strategy_max_stop_atr_mult | 2.50 | 0.5-10.0 | Maximum accepted stop distance as ATR multiple. |
| strategy_target_r_mult | 1.50 | 0.1-10.0 | Profit target in R multiple. |
| strategy_breakeven_r_mult | 1.00 | 0.1-5.0 | R multiple at which the stop moves to breakeven. |
| strategy_trail_atr_mult | 2.00 | 0.1-10.0 | ATR multiple used for trailing after the 1R threshold. |
| strategy_spread_stop_frac | 0.10 | 0.0-1.0 | Maximum spread as a fraction of stop distance. |
| strategy_max_hold_bars | 16 | 1-200 | Maximum holding period in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid forex major for H1 trend-pullback behavior.
- GBPUSD.DWX - card-listed liquid forex major for H1 trend-pullback behavior.
- XAUUSD.DWX - card-listed metal with DWX data and enough H1 volatility for ATR pullbacks.
- GDAXI.DWX - verified DWX DAX symbol used as the nearest available replacement for card-listed GER40.DWX.
- NDX.DWX - card-listed index proxy with DWX data for large-cap index trend-pullbacks.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 (revised 2026-06-16; was 45 over-estimate — see card freq note) |
| Typical hold time | Up to 16 H1 bars |
| Expected drawdown profile | Trend-continuation drawdown clustered during failed breakouts and range-bound reversals. |
| Regime preference | trend-continuation after thrust and pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, Fundamental Trading Patterns; The pullback: a trade that works.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10910_grimes-pullback.md`

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
| v1 | 2026-06-06 | Initial build from card | ab694e5c-293d-4fa9-b10d-6cde49a80a54 |
