# Strategy Card (mechanized) — H-MR: Cash-open index mean reversion (session-flat)

## Research provenance
Complement candidate to QM-RESEARCH-2026-0002 (H-CW), authored by Kimi
(research role, offline) under the interim OWNER strategy-engineering
delegation of 2026-09-15/16. H-CW takes the successful breakout side of the
cash-session opening range; H-MR takes the FAILED breakout side: the same
opening-auction reference that anchors continuation breakouts also anchors
reversion when the first impulse over-extends and fails. Offline statistical
instruments were used in research only (directive sec41); the rules below are
fully mechanical with no runtime model (directive sec42/sec51). Pilot
motivation (not proof) comes from a deterministic fire-count of the exact
rules below on a Dukascopy USATECHIDXUSD tick feed (NDX-class index CFD,
2018-2020, in-sample window; computed output `h_mr_fire_count.json`): the
first session bar's range sits at a median ~2.0x ATR(14) on that feed, so the
shock floor is placed at 3.0 to skip only extreme shock days, and the
midpoint-target reward/risk sits at a median ~0.7, so the minimum-R floor
defaults to 0.5.

## Structural cause
Equity-index CFDs at the cash open frequently over-extend on the first
impulse: the opening auction clears an inventory imbalance and runs resting
stops beyond the opening range, but when no fresh initiative flow follows, the
move is unsupported and price reverts toward the opening-auction reference
(the opening-range midpoint) within the session. Trading only the failed
breakout side, inside the cash window, and forcing flat before the thin
rollover removes the overnight gap and swap tails while keeping per-trade
expectancy high enough for moderate density to clear FTMO min-trading-day and
progression requirements.

## Price signature
During the cash-session window, price pierces the opening-range extreme by a
small ATR-scaled buffer on a single H1 bar and then closes back inside the
range on that same bar — a failed breakdown or failed breakout — while the
close sits on the stretched side of a short intraday EMA. The failed move
reverts toward the opening-range midpoint and the position is closed before
session end.

## Persistence
The effect rests on the recurring opening-auction mechanics of equity-index
CFDs (daily inventory reset, stop runs at the cash open) rather than a
one-off regime, so it is expected to persist; it is defended by hard
session-flat exits and a daily loss breaker rather than by a fragile
parameter. It is complementary to H-CW by construction: H-MR is profitable
exactly on the session days where the opening-range breakout fails, so the
pair diversifies the same window across breakout outcomes.

## Long entry (failed breakdown)
Enter long when ALL of the following hold on the same completed H1 bar
(shift 1), inside the entry window:
1. The bar's low is below the opening-range low minus
   ``breakout_buffer_atr`` times ATR(``atr_period``) (downside pierce).
2. The bar's close is back inside the opening range: strictly above the
   opening-range low AND strictly below the opening-range high.
3. The bar's close is below the EMA(``ema_period``) on H1 (stretched down).
4. The reward/risk measured at the market entry price is at least
   ``min_target_r``: (take-profit minus entry) >= ``min_target_r`` times
   (entry minus stop), with stop and take-profit defined below.
One entry per symbol per day.

## Short entry (failed breakout)
Enter short when ALL of the following hold on the same completed H1 bar,
inside the entry window:
1. The bar's high is above the opening-range high plus
   ``breakout_buffer_atr`` times ATR (upside pierce).
2. The bar's close is back inside the opening range: strictly below the
   opening-range high AND strictly above the opening-range low.
3. The bar's close is above the EMA(``ema_period``) on H1 (stretched up).
4. (entry minus take-profit) >= ``min_target_r`` times (stop minus entry).
One entry per symbol per day.

## No-trade conditions
Do not trade outside the session window. Do not open a new position when the
first session bar's range exceeds ``shock_atr_mult`` times ATR (news/vol
shock day), when the current spread exceeds ``spread_median_mult`` times its
20-day median at entry time, or when a scheduled high-impact event
(FOMC/NFP/CPI) falls inside the session blackout. No new position after
``friday_cutoff_hour_utc`` on Friday; no weekend carry.

## Exit
Exit at the profit target (opening-range midpoint), at the stop, at a
time-stop of ``time_stop_bars`` H1 bars, or at the mandatory session-flat
time ``flatten_hour_utc`` — whichever comes first. No overnight hold.

## Stop loss
Hard stop beyond the failed-breakout extreme plus an ATR buffer: for a long,
the signal bar's low minus ``atr_stop_mult`` times ATR(``atr_period``); for a
short, the signal bar's high plus ``atr_stop_mult`` times ATR, computed from
the ATR at signal time.

## Take profit
Fixed price target at the opening-range midpoint: (opening-range high +
opening-range low) / 2, computed once from the completed opening range. The
midpoint is the mechanizable opening-auction reference and the natural
reversion magnet; a session tick-volume VWAP proxy is rejected because .DWX
index CFD volume modelling is not validated. ``min_target_r`` is a minimum
reward:risk entry eligibility floor (not a TP multiple): trades whose
midpoint reward does not pay at least ``min_target_r`` times the stop risk
are skipped.

## Trailing logic
Optional break-even move once price has travelled one ATR in favour; bounded
and finite, never widening the stop.

## Position sizing
Risk a fixed fraction ``risk_per_trade_pct`` of equity per trade (RISK_FIXED
in backtest, RISK_PERCENT live); lot size derived deterministically from the
stop distance.

## Session rules
Entries allowed only between ``session_start_hour_utc`` and
``session_end_hour_utc`` (UTC), and only after the opening range
(``opening_range_bars`` first session bars) has completed; mandatory flat by
``flatten_hour_utc``. Maximum ``max_positions_total`` open positions at once
across this EA's symbol slots.

## Filters
Volatility/shock filter (skip the day when the first session bar's range >
``shock_atr_mult`` * ATR) and a spread filter (skip when spread >
``spread_median_mult`` * 20-day median). Daily circuit breaker: stop trading
for the day at ``daily_stop_pct`` day P&L; stop for the week at
``weekly_stop_pct``. No martingale or averaging.

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the
live MT5 news calendar. No external feed.

## Timeframe
H1 for signals (an M15 execution variant is allowed, mirroring the H-CW
card); no D1 or higher signals.

## Symbols
NDX, GDAXI, SP500 index CFDs (symbols are inputs, never code literals; one
input per symbol slot). No FX, no metals, no energy.

## Parameter ranges
- opening_range_bars: 2 .. 4
- ema_period: 15 .. 30
- breakout_buffer_atr: 0.0 .. 0.05
- atr_period: 10 .. 20
- atr_stop_mult: 0.5 .. 1.5
- min_target_r: 0.4 .. 0.8
- time_stop_bars: 4 .. 8
- risk_per_trade_pct: 0.20 .. 0.50
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 2.5 .. 4.0
- spread_median_mult: 1.25 .. 1.75
- session_start_hour_utc: 13 .. 14
- session_end_hour_utc: 16 .. 17
- flatten_hour_utc: 20 .. 21
- friday_cutoff_hour_utc: 17 .. 18
- max_positions_total: 1 .. 3
- news_blackout_minutes: 0 .. 120

## Expected frequency
At most one signal per day per symbol by construction. The deterministic
pilot fire count of these exact rules (NDX-class Dukascopy feed, 2018-2020
in-sample, computed output ``h_mr_fire_count.json``) recorded: 489 evaluated
session days, 135 gross signals, 82 taken trades, 2.9 trades/month and ~4.7
active days/month on that feed. Expect roughly 2-5 trades per month per
symbol, about 6-15 trades per month across the three index symbols, with at
least 3 active days per month per symbol — above the Q02 >=5 trades/yr floor
without entering the scalp class. The same pilot marked the raw pattern
PF(R) ~1.12 at +0.02R/trade with a ~30% midpoint-target hit rate on the proxy
feed: feasibility-level motivation only, BELOW the preregistered success bar
— the farm pipeline (filters, .DWX execution, Q00-Q17) must prove the edge,
and the preregistered kill criteria are the judge.

## Invalidation conditions
Refuted if, out of sample, session-flat cash-open mean reversion does not
reduce worst-day loss or breach probability relative to the swing baseline
(and to the H-CW continuation sibling), or if the edge depends on a single
symbol or single period.

## Falsification / kill criteria
Killed if: OOS holdout net profit factor < 1.20 after costs or expectancy
< +0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) > 2% or
simulated worst-day p95 > 2.5% of equity at 0.25% risk; realized
swap/rollover cost > 10% of gross P&L; more than half of the +-1-step
parameter neighbourhood shows negative expectancy; any single month has < 3
active days on a traded symbol; or the strategy does not reduce worst-day
loss or breach probability relative to the swing baseline out of sample.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk; the shock and spread
filters and the live news filter fail closed. Q08 stress and Q11
full-history confirmation remain the judges before any book placement.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop), a hard daily loss
breaker, and a high-hit-rate midpoint target with moderate density target the
probability of completing the challenge rather than standalone profit
factor. The daily breaker (-1.0%) and weekly breaker (-2.0%) sit far inside
the FTMO 5% daily and 10% total drawdown limits, and the high-impact news
blackout keeps FOMC/NFP/CPI windows closed. As the failed-breakout complement
of H-CW it diversifies the same FTMO-friendly window across breakout
outcomes rather than doubling the continuation exposure.
