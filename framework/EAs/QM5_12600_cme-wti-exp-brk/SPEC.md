# QM5_12600_cme-wti-exp-brk - Strategy Spec

**EA ID:** QM5_12600
**Slug:** `cme-wti-exp-brk`
**Source:** `CME-WTI-EXPIRY-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI futures expiry/roll-window
sleeve on `XTIUSD.DWX`. On each new D1 bar, it evaluates only the prior closed
bar and only when that bar falls inside a calculated monthly CME WTI
termination window. A strong upside breakout opens a long position; a strong
downside breakout opens a short position. Both sides require SMA trend
confirmation, minimum ATR-normalized range, and close-location confirmation.

The strategy is intentionally not a duplicate of the existing WTI family:
weekday and month-of-year calendar effects, broad EIA petroleum seasonality,
weekly WPSR setups, hurricane supply risk, refinery-turnaround fades, OPEC
policy windows, and medium-term return reversal all use different timing or
entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 12 | 8-20 | Prior completed D1 bars for breakout entry |
| `strategy_exit_channel` | 6 | 4-10 | Prior completed D1 bars for failed-breakout exit |
| `strategy_trend_period` | 50 | 34-84 | SMA trend confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and range filter |
| `strategy_min_range_atr` | 0.75 | 0.60-1.00 | Prior-bar range floor as ATR multiple |
| `strategy_min_close_location` | 0.65 | 0.60-0.75 | Close location threshold within prior-bar range |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 6 | 4-9 | Calendar-day stale-position guard |
| `strategy_expiry_pre_days` | 3 | 2-5 | Days before calculated expiry eligible for entry |
| `strategy_expiry_post_days` | 2 | 1-3 | Days after calculated expiry eligible for entry |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-12.
- Typical hold: several D1 bars; capped at 6 calendar days by default.
- Regime preference: monthly WTI futures expiration and contract-roll windows.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

CME Group, "Chapter 200 Light Sweet Crude Oil Futures", URL
https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf. Supplement: CME Group,
"Understanding Futures Expiration & Contract Roll", URL
https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
