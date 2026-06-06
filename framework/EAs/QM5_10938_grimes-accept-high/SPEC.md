# QM5_10938_grimes-accept-high - Strategy Spec

**EA ID:** QM5_10938
**Slug:** grimes-accept-high
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 continuation after price breaks a 40-bar high or low and then accepts around the old breakout level. For a long, D1 must close above EMA(20) with the EMA rising over five bars, an H1 bar must close above the prior 40-bar high after an impulse of at least 2 ATR(20), and the next 4 to 16 H1 closes must mostly hold above the old high without a deep failure. It enters long when a later H1 close clears the acceptance range high; shorts mirror the same rules below a 40-bar low. The stop is placed 0.25 ATR beyond the acceptance range, target is 2R, breakeven is applied at 1R, and the trade exits after two H1 closes back through the old breakout level or after 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_breakout_lookback` | `40` | 10-120 | Prior H1 bars used for breakout high or low. |
| `strategy_acceptance_min_bars` | `4` | 1-16 | Minimum H1 bars in the post-breakout acceptance window. |
| `strategy_acceptance_max_bars` | `16` | 4-32 | Maximum H1 bars in the post-breakout acceptance window. |
| `strategy_acceptance_close_fraction` | `0.70` | 0.50-1.00 | Required fraction of acceptance closes that hold the old level. |
| `strategy_acceptance_fail_atr_mult` | `0.50` | 0.10-2.00 | Maximum allowed close-through failure beyond the old level in ATR units. |
| `strategy_atr_period` | `20` | 5-80 | ATR period used for impulse, stop, and filter distances. |
| `strategy_impulse_atr_mult` | `2.0` | 0.5-6.0 | Minimum breakout impulse from last swing to breakout extreme. |
| `strategy_breakout_bar_atr_max` | `3.0` | 1.0-8.0 | Rejects breakout bars with range above this ATR multiple. |
| `strategy_stop_atr_buffer` | `0.25` | 0.0-2.0 | ATR buffer beyond the acceptance low or high for the initial stop. |
| `strategy_max_stop_atr_mult` | `2.5` | 0.5-8.0 | Rejects setups whose stop distance exceeds this ATR multiple. |
| `strategy_acceptance_width_fraction` | `0.50` | 0.10-1.00 | Rejects acceptance ranges wider than this fraction of the measured impulse. |
| `strategy_ema_period` | `20` | 5-100 | D1 EMA period for trend filter. |
| `strategy_ema_slope_bars` | `5` | 1-20 | Bars between current and prior D1 EMA value for slope check. |
| `strategy_tp_rr` | `2.0` | 0.5-5.0 | Fixed reward-to-risk target. |
| `strategy_be_trigger_rr` | `1.0` | 0.5-3.0 | Reward-to-risk threshold for breakeven stop move. |
| `strategy_max_hold_bars` | `24` | 1-96 | Maximum H1 bars to hold a trade. |
| `strategy_spread_stop_fraction` | `0.08` | 0.01-0.50 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol directly matches the source market context.
- `NDX.DWX` - Nasdaq 100 is a liquid US large-cap index continuation proxy.
- `WS30.DWX` - Dow 30 is a liquid US large-cap index continuation proxy.
- `GDAXI.DWX` - Matrix-valid DAX symbol used as the available DWX port for card-stated `GER40.DWX`.
- `XAUUSD.DWX` - Gold is included by the approved card's portable basket and supports H1 trend-continuation testing.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX` - Not the canonical S&P 500 custom symbol; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` EMA(20) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | Up to 24 H1 bars |
| Expected drawdown profile | Bounded 1R initial risk with 2R target and 1R breakeven protection. |
| Regime preference | Trend-continuation after price acceptance near prior highs or lows. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Patterns, Context, and a Clean Long in the S&P", 2025-08-25, https://www.adamhgrimes.com/patterns-context-and-a-clean-long-in-the-s-p/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10938_grimes-accept-high.md`

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
| v1 | 2026-06-06 | Initial build from card | 8e90859a-b9d1-4ee6-8814-4d6a5d6c0cbb |
