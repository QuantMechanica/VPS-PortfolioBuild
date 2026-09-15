# Strategy Card (mechanized) — H-CW: Cash-window index continuation (session-flat)

## Research provenance
Discovered by the first autonomous edge-discovery campaign (CAMP-2026-0001, directive
sec47/sec68 PHASE G).  Kimi (research role, offline) analysed a deterministic OBSERVE
projection of QuantMechanica's own backtest evidence and identified the farm's only
deeply-validated FTMO-shaped pocket: index intraday at the terminal gate (9 of 10 index
intraday/scalp Q10 rows PASS).  Offline statistical instruments are permitted in research
only (directive sec41); the rules below are fully mechanical with no runtime model
(directive sec42/sec51).

## Structural cause
Equity-index CFDs exhibit persistent intraday order flow during the cash-session overlap
(deepest liquidity, tightest spread, strongest autocorrelated tape).  Confining trades to
that window and forcing flat before the thin rollover removes the two tails that kill
FTMO accounts — overnight gap and swap — while an H1 timeframe keeps per-trade expectancy
high enough that moderate density clears the challenge's min-trading-day and progression
requirements without scalp-class noise.

## Price signature
During the cash-session window price breaks the range of the first few session bars and
continues in the breakout direction while above/below a short intraday moving average; the
move is captured for a bounded number of bars and closed before session end.

## Persistence
The effect rests on recurring cash-session inventory and index order flow rather than a
one-off regime, so it is expected to persist; it is defended by hard session-flat exits
and a daily loss breaker rather than by a fragile parameter.

## Long entry
Enter long when the close of the current H1 bar is above the maximum high of the first
``breakout_window_bars`` H1 bars of the session AND the close is above the ``ema_period``
EMA on H1.  One entry per symbol per day.

## Short entry
Enter short when the close of the current H1 bar is below the minimum low of the first
``breakout_window_bars`` H1 bars of the session AND the close is below the ``ema_period``
EMA on H1.  One entry per symbol per day.

## No-trade conditions
Do not trade outside the session window.  Do not open a new position when the first
session bar's range exceeds ``shock_atr_mult`` times ATR(``atr_period``) (news/vol shock),
when the current spread exceeds ``spread_median_mult`` times its 20-day median at entry
time, or when a scheduled high-impact event (FOMC/NFP/CPI) falls inside the session
blackout.  No new position after ``friday_cutoff_hour_utc`` on Friday; no weekend carry.

## Exit
Exit at the profit target (``target_r`` times risk), at the stop, at a time-stop of
``time_stop_bars`` H1 bars, or at the mandatory session-flat time ``flatten_hour_utc`` —
whichever comes first.  No overnight hold.

## Stop loss
Hard stop at ``atr_stop_mult`` times ATR(``atr_period``) from entry.

## Take profit
Fixed reward-to-risk target at ``target_r`` times the stop distance.

## Trailing logic
Optional break-even move once price has travelled one ATR in favour; bounded and finite,
never widening the stop.

## Position sizing
Risk a fixed fraction ``risk_per_trade_pct`` of equity per trade (RISK_FIXED in backtest,
RISK_PERCENT live); lot size derived deterministically from the stop distance.

## Session rules
Entries allowed only between ``session_start_hour_utc`` and ``session_end_hour_utc``
(broker time); mandatory flat by ``flatten_hour_utc``.  Maximum ``max_positions_total``
open positions at once.

## Filters
Volatility/shock filter (skip when first-bar range > ``shock_atr_mult`` * ATR) and a
spread filter (skip when spread > ``spread_median_mult`` * 20-day median).  Daily circuit
breaker: stop trading for the day at ``daily_stop_pct`` day P&L; stop for the week at
``weekly_stop_pct``.  No martingale or averaging.

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the live MT5 news
calendar.  No external feed.

## Timeframe
H1 for signals (an M15 execution variant, present in the farm's own Q10 passes, is
allowed); no D1 or higher signals.

## Symbols
NDX, GDAXI, SP500 index CFDs (symbols are inputs, never code literals; one input per
symbol slot).  No FX, no metals, no energy.

## Parameter ranges
- breakout_window_bars: 2 .. 4
- ema_period: 15 .. 30
- breakout_buffer_atr: 0.0 .. 0.05
- atr_period: 10 .. 20
- atr_stop_mult: 1.0 .. 1.0
- target_r: 1.5 .. 2.0
- time_stop_bars: 4 .. 8
- risk_per_trade_pct: 0.20 .. 0.50
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 1.5 .. 2.5
- spread_median_mult: 1.25 .. 1.75
- session_start_hour_utc: 13 .. 14
- session_end_hour_utc: 16 .. 17
- flatten_hour_utc: 20 .. 21
- friday_cutoff_hour_utc: 17 .. 18
- max_positions_total: 1 .. 3
- news_blackout_minutes: 0 .. 120

## Expected frequency
At most one signal per day per symbol: roughly 18-22 trades per month per symbol, about
55-65 trades per month across the three index symbols, with at least 12 active days per
month — the same density order as the scored population mean, well above the Q02 >=5
trades/yr floor and without entering the scalp class.

## Invalidation conditions
Refuted if, out of sample, session-flat index continuation does not reduce worst-day loss
or breach probability relative to the swing baseline, or if the edge depends on a single
symbol or single period.

## Falsification / kill criteria
Killed if: OOS holdout net profit factor < 1.20 after costs or expectancy < +0.10R/trade;
Monte-Carlo P(hit -5% daily limit within 60d) > 2% or simulated worst-day p95 > 2.5% of
equity at 0.25% risk; realized swap/rollover cost > 10% of gross P&L; more than half of the
+-1-step parameter neighbourhood shows negative expectancy; or any single month has < 8
active days.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk; the shock and spread filters and the
live news filter fail closed.  Q08 stress and Q11 full-history confirmation remain the
judges before any book placement.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop), a hard daily loss breaker, and a
progression-friendly R-target with moderate density target the probability of completing
the challenge rather than standalone profit factor — the opposite shape to the D1 gold/FX
swing pocket whose overnight/swap tail produced the -10.26% demo breach.
