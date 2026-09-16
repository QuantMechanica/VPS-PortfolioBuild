# Strategy Card (mechanized) — H-FXMR: FX session mean reversion (session-flat, M15)

## Research provenance
Second FTMO-gap candidate in the QM-RESEARCH-2026-0002 series (OWNER master
directive 2026-09-15: continuous book evolution / FTMO acceleration; interim
OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-16).  The H-CW build (QM5_41475)
covered the index-intraday continuation pocket; the universe map of the farm's
exercised universe (``universe_map_result.json``, deterministic projector over
``farm_state.sqlite``, 14,939 exercised ea_id x symbol pairs) shows the whole
high-density FTMO-fit class at 128 pairs = 0.86% of the universe, every FX
cell at 0 FTMO incumbents, and session-specified FX intraday/scalp
mean-reversion coverage of 8 pairs (0 FTMO incumbents) — the FTMO book has no
high-density, short-holding, low-swap FX sleeve.  FX intraday mean reversion in the liquid London/New York
session windows is the canonical density engine for that white space.  Authored
and mechanized by Kimi (interim strategy-engineering delegation); offline
statistical instruments were used in research only (directive sec41); the rules
below are fully mechanical with no runtime model (directive sec42/sec51).

## Structural cause
Major FX pairs are the deepest, tightest-spread instruments the farm trades, and
their intraday flow exhibits short-horizon overextension-reversion: during the
London and New York sessions, runs of consecutive same-direction M15 bars push
price away from a short EMA faster than the session's information flow can
sustain, and the close back through the EMA marks the inventory-clearing snap.
Confining entries to the two liquid session windows, bounding the holding to a
handful of M15 bars, and forcing flat before each session's close removes the
overnight gap and swap tails (swap ~ 0 for session-flat FX) while the M15
density clears the challenge's minimum-activity and progression requirements.

## Price signature
During a session window, price prints ``stretch_bars`` or more consecutive
same-direction M15 closes (or closes stretched beyond ``stretch_atr_mult`` x ATR
from the short EMA), then the next completed bar closes back through the EMA in
the opposite direction — the reversion entry.  The trade targets a fixed
fraction of the stretch, stopped beyond the stretch extreme, and is closed by
time-stop or session-flat if neither level is hit.

## Persistence
The effect rests on recurring session inventory cycles (London fix flow, New
York cross flow) rather than a one-off regime; it is defended by hard
session-flat exits, a per-day trade cap and a daily loss breaker rather than by
a fragile parameter.

## Long entry
Enter long when, on the just-closed M15 bar (shift 1) inside a session entry
window: (a) the close crossed back above the ``ema_period`` EMA
(close1 > EMA1 and close2 <= EMA2 at the prior closed bar), and (b) the prior
bar was stretched down: the run of consecutive down-closes ending at bar 2 has
length >= ``stretch_bars``, or bar 2 closed more than ``stretch_atr_mult`` x
ATR below its EMA.  One entry per symbol per session window; at most
``max_trades_per_day`` entries per symbol per UTC day.

## Short entry
Enter short when the mirror holds: close1 < EMA1 and close2 >= EMA2, and the
prior bar was stretched up (run of consecutive up-closes ending at bar 2 of
length >= ``stretch_bars``, or bar 2 closed more than ``stretch_atr_mult`` x ATR
above its EMA).

## No-trade conditions
Do not trade outside the two session entry windows
(``london_start_hour_utc``..``london_end_hour_utc``,
``ny_start_hour_utc``..``ny_end_hour_utc`` UTC), in the first
``skip_first_minutes`` after a window opens, when the window's first M15 bar
range exceeds ``shock_atr_mult`` x ATR (news/vol shock), when the current spread
exceeds ``spread_median_mult`` x its 20-day median, when a scheduled
high-impact event for the pair's currencies falls inside the session blackout
(``news_blackout_minutes``, fail-closed), after ``friday_cutoff_min_utc`` on
Friday, when the daily breaker (-1.0%) or weekly breaker (-2.0%) has hit, when
``max_trades_per_day`` is reached for the symbol-day, or when
``max_positions_total`` family positions are open.  No new position within
``flat`` proximity of a session end.  No weekend carry.

## Exit
Exit at the profit target (``target_r`` x stop distance), at the stop
(stretch extreme + ``stop_buffer_atr`` x ATR buffer), at a time-stop of
``time_stop_bars`` M15 bars, at the mandatory session-flat minute
(``london_flat_min_utc`` / ``ny_flat_min_utc``), or at the daily-flat backstop —
whichever comes first.  No overnight hold.

## Stop loss
Hard stop at the stretch extreme of the entry window (the lowest low of the
last ``stretch_bars`` stretch bars for a long, highest high for a short) minus
(plus, for a short) ``stop_buffer_atr`` x ATR at signal.  If that distance
exceeds ``max_stop_atr`` x ATR the trade is skipped (poor reversion R:R).

## Take profit
Fixed reward-to-risk at ``target_r`` x the stop distance.  The 1.0-1.5R band
(default 1.25R) is chosen because session mean-reversion edge decays quickly
after the reclaim; a moderate fixed R keeps expectancy positive while the
density (not the per-trade R multiple) drives challenge progression.

## Trailing logic
None.  The stop is placed once beyond the stretch extreme and is never widened;
break-even management is intentionally absent (a re-entry stop beyond the
extreme is the thesis invalidation point, and partial management would
complicate the bounded contract).

## Position sizing
Risk a fixed fraction ``risk_per_trade_pct`` of equity per trade (RISK_FIXED in
backtest, RISK_PERCENT live); lot size derived deterministically from the stop
distance.  No martingale, no averaging, no grid, no pyramiding.

## Session rules
Entries allowed only inside the two UTC windows (defaults London 07:00-11:00,
New York 12:00-16:00, broker time mapped via QM_DSTAware); mandatory flat by
``london_flat_min_utc`` (11:30) for the London window and ``ny_flat_min_utc``
(16:30) for the New York window; nothing held between windows.  Maximum
``max_positions_total`` open positions across the EA family.

## Filters
Volatility/shock filter (skip the window when its first bar range >
``shock_atr_mult`` x ATR), spread filter (skip when spread >
``spread_median_mult`` x 20-day median), fail-closed high-impact news blackout
for the pair's currencies, daily circuit breaker at ``daily_stop_pct`` (-1.0%)
and weekly at ``weekly_stop_pct`` (-2.0%), optional skip-first-minutes after
session open, per-day per-symbol trade cap ``max_trades_per_day``.

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the live
MT5 news calendar.  No external feed.

## Timeframe
M15 for signals and execution; no D1 or higher signals.

## Symbols
EURUSD, GBPUSD, USDJPY FX majors (symbols are inputs, never code literals; one
input per symbol slot, ``.DWX`` in research/backtest).  No indices, metals,
energy.

## Parameter ranges
- stretch_bars: 2 .. 4
- ema_period: 10 .. 20
- stretch_atr_mult: 0.5 .. 1.5
- atr_period: 10 .. 20
- stop_buffer_atr: 0.1 .. 0.5
- max_stop_atr: 1.5 .. 2.5
- target_r: 1.0 .. 1.5
- time_stop_bars: 8 .. 16
- risk_per_trade_pct: 0.20 .. 0.50
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 1.5 .. 2.5
- spread_median_mult: 1.25 .. 1.75
- london_start_hour_utc: 7 .. 8
- london_end_hour_utc: 10 .. 12
- ny_start_hour_utc: 12 .. 13
- ny_end_hour_utc: 15 .. 16
- london_flat_min_utc: 660 .. 720
- ny_flat_min_utc: 960 .. 1020
- friday_cutoff_min_utc: 780 .. 900
- skip_first_minutes: 0 .. 30
- max_positions_total: 2 .. 4
- max_trades_per_day: 2 .. 6
- news_blackout_minutes: 0 .. 120

## Expected frequency
Bounded by one entry per symbol per session window (max 2 windows/day) and the
``max_trades_per_day`` cap: roughly 18-28 trades per month per symbol, about
55-85 trades per month across the three FX symbols, with at least 15 active
days per month — the high-density FTMO-fit cell the universe map shows as
uncovered.

## Invalidation conditions
Refuted if, out of sample, session-window FX mean reversion does not reduce
worst-day loss or breach probability relative to the farm's FX swing baseline,
or if the edge depends on a single symbol, a single session window, or a single
parameter island.

## Falsification / kill criteria
Killed if: OOS holdout net profit factor < 1.20 after costs or expectancy <
+0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) > 2% or simulated
worst-day p95 > 2.5% of equity at 0.25% risk; realized swap/rollover cost >
10% of gross P&L; more than half of the +/-1-step parameter neighbourhood shows
negative expectancy; any single month has < 10 active days; or the per-day
trade cap must be raised above 6 to clear the activity floor.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk; the shock and spread filters
and the fail-closed news blackout cover event risk inside the windows.  Q08
stress and Q11 full-history confirmation remain the judges before any book
placement.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop), a hard daily loss
breaker at half the challenge's daily limit, bounded holding minutes, and a
high but capped density target the probability of completing the challenge —
the opposite shape to the D1 FX/gold swing pocket whose overnight/swap tail
produced the -10.26% demo breach.
