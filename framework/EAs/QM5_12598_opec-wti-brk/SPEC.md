# QM5_12598_opec-wti-brk - Strategy Spec

**EA ID:** QM5_12598
**Slug:** `opec-wti-brk`
**Source:** `OPEC-WTI-CONF-BRK-2026`
**Author of this spec:** Codex / Claude
**Last revised:** 2026-07-05

## 1. Strategy Logic

This EA implements a low-frequency structural WTI supply-policy risk sleeve on
`XTIUSD.DWX`. On each new D1 bar, it evaluates only the prior closed bar and
only when that bar falls inside the fixed OPEC ordinary-meeting risk windows:
June and December, day 1 through day 14 by default. A strong upside breakout
opens a long position; a strong downside breakout opens a short position. Both
sides require SMA trend confirmation, minimum ATR-normalized range, and close
location confirmation.

The strategy is intentionally not a duplicate of the existing WTI family:
monthly petroleum demand seasonality, weekly WPSR setups, hurricane supply risk,
refinery-turnaround fades, weekday effects, and medium-term return reversal all
use different timing and entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 10 | 8-20 | Prior completed D1 bars for breakout entry |
| `strategy_exit_channel` | 5 | 4-10 | Prior completed D1 bars for failed-breakout exit |
| `strategy_trend_period` | 50 | 34-84 | SMA trend confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and range filter |
| `strategy_min_range_atr` | 0.70 | 0.50-1.10 | Prior-bar range floor as ATR multiple |
| `strategy_min_close_location` | 0.65 | 0.60-0.75 | Close location threshold within prior-bar range |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position guard |
| `strategy_event_month_a` | 6 | 6 | June OPEC window |
| `strategy_event_month_b` | 12 | 12 | December OPEC window |
| `strategy_window_start_day` | 1 | 1 | First eligible day of month |
| `strategy_window_end_day` | 14 | 10-18 | Last eligible day of month |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: several D1 bars; capped at 8 calendar days by default.
- Regime preference: OPEC ordinary-meeting supply-policy risk windows.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

OPEC, "OPEC holds 181st Meeting of the Conference", URL
https://www.opec.org/pn-detail/86-15-june-2021.html. Supplement: U.S. Energy
Information Administration, "Oil supply and OPEC", URL
https://www.eia.gov/finance/markets/crudeoil/supply-opec.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial build from card | eefacdeb9 |
| v2 | 2026-07-05 | Rebuild in place (DL-069): prior build had the pre-2026-07-02 OnTick ordering (2-axis news gate above Strategy_ManageOpenPosition/ExitSignal), which silently suspends the strategy's channel/SMA/window/time-stop exits during news windows. Reordered to canonical kill-switch -> Friday-close -> NoTradeFilter -> ManageOpenPosition -> ExitSignal -> news gate -> IsNewBar -> EntrySignal, with per-bar state cached once via Strategy_AdvanceStateOnNewBar() so Management stays O(1) per tick. No change to entry/exit rules or params. | 78af9e87-f2bf-40c3-882b-1ba00329fed0 |
