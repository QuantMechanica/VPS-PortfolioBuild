# QM5_10919_grimes-overshoot - Strategy Spec

**EA ID:** QM5_10919
**Slug:** `grimes-overshoot`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 climax reversals after a mature trend overshoots a Keltner-style EMA20 +/- 2.25 ATR20 channel. A short setup requires price above EMA50 with EMA50 rising for 30 bars, an upside acceleration, a wide-range new 20-bar high, and a weak close in the lower 35% of the exhaustion bar; the long setup mirrors those conditions after a downside overshoot. After detecting an exhaustion bar, the EA waits up to three subsequent H4 bars and enters at market when the last closed bar traded beyond the exhaustion low for shorts or high for longs. It uses the exhaustion extreme plus 0.25 ATR20 as the stop, rejects stops above 3.5 ATR20, places a 2R target, partially closes at 1R, exits on EMA20 touch, and time-exits after 12 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 expected | Signal timeframe from the card. |
| `strategy_ema_period` | `20` | `>1` | Keltner midline and EMA-touch exit period. |
| `strategy_mature_ema_period` | `50` | `>1` | Mature-trend EMA period. |
| `strategy_atr_period` | `20` | `>1` | ATR period for channel, exhaustion, and stop rules. |
| `strategy_channel_atr_mult` | `2.25` | `>0` | Keltner channel ATR multiplier. |
| `strategy_accel_atr_mult` | `2.00` | `>0` | Minimum EMA20 distance for acceleration. |
| `strategy_mature_slope_bars` | `30` | `>=1` | Consecutive EMA50 slope bars required. |
| `strategy_breakout_lookback` | `20` | `>=2` | New high/new low lookback. |
| `strategy_exhaust_range_atr` | `1.50` | `>0` | Minimum exhaustion-bar range in ATR. |
| `strategy_exhaust_close_frac` | `0.35` | `0-1` | Weak/strong close location threshold. |
| `strategy_trigger_window_bars` | `3` | `>=1` | Bars allowed after exhaustion for trigger. |
| `strategy_stop_buffer_atr` | `0.25` | `>=0` | Stop buffer beyond exhaustion extreme. |
| `strategy_max_stop_atr` | `3.50` | `>0` | Maximum allowed stop distance. |
| `strategy_target1_r` | `1.00` | `>0` | Partial-close trigger in R. |
| `strategy_target2_r` | `2.00` | `>0` | Final TP distance in R. |
| `strategy_time_exit_bars` | `12` | `>=0` | Maximum H4 bars held. |
| `strategy_max_spread_stop_frac` | `0.10` | `>=0` | Spread cap as fraction of stop distance. |
| `strategy_grimes_slide_ea_id` | `10918` | `>0` | Blocks opposite entries against active grimes-slide positions. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - liquid metal market where trend exhaustion and reversal bars are testable.
- `XTIUSD.DWX` - liquid oil market where trend overshoots are testable.
- `SP500.DWX` - S&P 500 custom symbol from the card; valid for backtest-only P2 coverage.
- `NDX.DWX` - Nasdaq 100 index exposure from the card's portable DWX basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX custom-symbol data.

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
| Trades / year / symbol | `12` |
| Typical hold time | H4 reversal hold, capped at 12 H4 bars |
| Expected drawdown profile | Conservative mature-trend climax reversal with bounded stop distance |
| Regime preference | Mature-trend overshoot reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "Overshoots and Overreactions" and "Did you miss a trade?"
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10919_grimes-overshoot.md`

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
| v1 | 2026-06-06 | Initial build from card | a6f8f086-3030-4dcd-a463-41346aeed7db |
