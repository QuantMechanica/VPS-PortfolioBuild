# QM5_12579_eia-wti-aftershock - Strategy Spec

**EA ID:** QM5_12579
**Slug:** `eia-wti-aftershock`
**Source:** `EIA-WTI-WPSR-AFTERSHOCK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
On each new D1 bar, it inspects the prior closed D1 bar only when that bar was
Wednesday or Thursday. If the event-day range expands versus ATR(20), the body
is directional, and the close confirms versus SMA(50), the EA enters in the
event-day direction. The position has a fixed ATR stop and exits after a short
calendar-day aftershock window.

The strategy is intentionally not a duplicate of the existing M5 inventory
release straddle (`QM5_1121`) or the monthly WTI seasonality card (`QM5_12576`).
It uses post-event D1 reaction only and never trades before the event day has
closed.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter and stop |
| `strategy_trend_period` | 50 | 34-84 | SMA confirmation period |
| `strategy_min_range_atr` | 1.15 | 1.0-1.6 | Minimum event-day range versus ATR |
| `strategy_min_body_ratio` | 0.35 | 0.25-0.5 | Minimum absolute body/range ratio |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 3 | 2-5 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 12.
- Typical hold: 2-5 D1 bars.
- Regime preference: WTI information-event range expansion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL
https://www.eia.gov/petroleum/supply/weekly/. Release schedule URL
https://www.eia.gov/petroleum/supply/weekly/schedule.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
