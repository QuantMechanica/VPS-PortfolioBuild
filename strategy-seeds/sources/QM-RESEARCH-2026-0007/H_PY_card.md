# Strategy Card (mechanized) — H-PY: bounded positive pyramid on cash-session index trend (session-flat)

## Research provenance
First TAIL_RISK programme candidate (Family A — bounded positive pyramiding),
authored by Kimi (research role, offline) under the interim OWNER delegation of
2026-09-15/16, per `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` §4 and the
machine-readable bounds in `tools/strategy_farm/config/tail_risk_families.v1.json`.
The base entry reuses the H-CW session-flat envelope
(`strategy-seeds/sources/QM-RESEARCH-2026-0002/H_CW_card.md`, QM5_41475): the
same cash-session opening-range breakout on NDX/GDAXI/SP500 H1, the same
shock/spread/news filter class, the same flatten hour and daily breakers. H-PY
adds the Family A pyramid on top: levels 2/3 added to a confirmed winner behind
a never-widening trailing giveback stop, so the tail of a built-out basket is
late-trend giveback monetized by the 50% giveback stop — never an overnight
gap, because the book is flat before rollover. Offline statistical instruments
were used in research only (directive sec41); every rule below is fully
mechanical with no runtime model (directive sec42/sec51). Pilot motivation
(not proof) comes from a deterministic fire count of the exact rules below on
a Dukascopy USATECHIDXUSD tick feed (NDX-class index CFD, 2018-2020 in-sample;
computed output `h_py_pilot.json`): the 13:00 session bar's range sits at a
median ~2.8x ATR(14) on that feed, so the shock floor defaults to 3.0 to skip
only extreme shock days. The pilot records 185 baskets over 29 months (6.4
baskets/month, ~6.4 active days/month) with raw PF(R) 1.26 at +0.12R/basket,
level-2 reach 11.9%, level-3 reach 0%, 15% of baskets giveback-stopped before
level 2 — in-sample, zero-cost, single-feed feasibility motivation only; the
frozen 2021-2024 holdout and the governed Q00-Q17 pipeline are the judges.

## Structural cause
Equity-index CFDs exhibit persistent intraday order flow during the cash-session
overlap (deepest liquidity, tightest spread, strongest autocorrelated tape).
When the session opening range breaks and the breakout holds above/below a
short intraday EMA, the directional flow that funded the break frequently
persists for several more hours — long enough to pay a trailed pyramid, and
long enough that a giveback stop set at 50% of peak open basket profit
monetizes the fat right tail of those sessions instead of donating it back at
the close. The mechanism is convexity, not prediction: exposure concentrates
only after the tape has already moved in favour (each add requires both an
ATR-scaled open profit and a new favourable extreme), so the position is
largest exactly when the session trend has confirmed itself, and the
never-widening basket stop converts parabolic reversals into small realised
givebacks rather than open-ended losses. Confining the whole construction to
the cash window and forcing flat before the thin rollover removes the two
tails that kill FTMO accounts — overnight gap and swap — which is precisely
the tail a built-out basket fears most.

## Price signature
During the cash-session window price breaks the range of the first session
bars and continues in the breakout direction while holding on the confirmed
side of a short intraday EMA. Favourable closes stack: first +1.0x ATR of open
profit with a new favourable extreme (level 2 fills), later +2.0x ATR with a
second new extreme (level 3 fills). The signature ends in one of three shapes:
a vertical extension whose giveback from the peak triggers the basket exit at
+50% retained profit, a drift that the trailing stop later harvests, or a
chop that stops the base leg at its ATR stop or runs into the session-flat
flatten.

## Persistence
The effect rests on recurring cash-session inventory and index order flow
rather than a one-off regime, so it is expected to persist; it is defended by
hard session-flat exits, the never-widening basket stop, the giveback stop,
and the daily loss breaker rather than by a fragile parameter. The pyramid
parameters (add spacing, giveback fraction, level weights) are programme-fixed
or range-bounded around the Family A contract, so the construction cannot
drift into negative-pyramiding or martingale shapes without violating its own
card.

## Expected mechanism
Convex capture of strong intraday trends. The base leg pays the discovery
cost on every session that breaks out; the adds are paid for only by sessions
whose trend persists (exposure concentrates where the tape has confirmed
direction), and the giveback stop monetizes the right tail of those sessions
at 50% of peak. Expectancy per basket should exceed expectancy of the flat
base-leg version only if cash-session trends persist long enough to print a
new favourable extreme after +1.0x ATR more often than they reverse violently
through the giveback stop first.

## Long entry (base leg, level 1)
Enter long when the close of the current H1 bar is above the maximum high of
the first ``breakout_window_bars`` H1 bars of the session plus
``breakout_buffer_atr`` times ATR(``atr_period``) AND the close is above the
``ema_period`` EMA on H1. The entry fills at the open of the next H1 bar.
One basket per symbol per day.

## Short entry (base leg, level 1)
Enter short when the close of the current H1 bar is below the minimum low of
the first ``breakout_window_bars`` H1 bars of the session minus
``breakout_buffer_atr`` times ATR AND the close is below the
``ema_period`` EMA on H1. The entry fills at the open of the next H1 bar.
One basket per symbol per day.

## Pyramid adds (levels 2 and 3)
Adds are evaluated on completed H1 bar closes while the basket is open and
fill at the next bar's open; one add per bar maximum; no add fills into the
flatten-hour bar; no adds on Friday after ``friday_cutoff_hour_utc``.
- Level 2 (size ``level2_size_mult`` x base): the bar's close shows open
  profit on the base leg of at least ``add2_trigger_atr`` times ATR measured
  at signal time, AND the bar prints a new favourable extreme versus every
  bar since the base entry (for a long: high greater than the highest high
  since entry; mirrored for a short).
- Level 3 (size ``level3_size_mult`` x base): the bar's close shows open
  profit on the base leg of at least ``add3_trigger_atr`` times ATR, AND a
  second new favourable extreme prints after the level-2 fill.
ATR for all add triggers is the ATR(``atr_period``) computed once at base
signal time. Hard bound: never more than 3 legs and never more than 2.25 base
legs aggregate per basket; the add logic fails closed at the bound (no further
adds even if triggers repeat).

## No-trade conditions
Do not trade outside the session window. Do not open a new basket when the
first session bar's range exceeds ``shock_atr_mult`` times ATR(``atr_period``)
(news/vol shock day), when the current spread exceeds
``spread_median_mult`` times its 20-day median at entry time, or when a
scheduled high-impact event (FOMC/NFP/CPI) falls inside the session blackout.
No new basket after ``friday_cutoff_hour_utc`` on Friday; no weekend carry.

## Exit
The whole basket exits together (all filled levels) at whichever triggers
first:
1. Session flat: mandatory flat at ``flatten_hour_utc`` (exit at the open of
   the flatten-hour bar). No overnight hold.
2. Basket stop: intrabar touch of the never-widening basket stop (see Trailing
   logic).
3. Hard equity adverse bound: basket open P&L reaches
   ``basket_adverse_bound_pct`` of equity against the basket (the Family A
   0.5% hard bound; -2R at the 0.25% default base risk).
4. Giveback stop: basket open P&L gives back ``giveback_frac`` of the peak
   open basket P&L (Family A 50% giveback), with the peak tracked from basket
   open on every bar close.
5. Time stop: ``time_stop_bars`` H1 bars after base entry.

## Stop loss
Level-1 reference stop: ``atr_stop_mult`` times ATR(``atr_period``) from the
base fill price. After level 2 fills, the basket stop ratchets to the blended
breakeven of the filled levels plus ``be_buffer_atr`` times ATR (breakeven
plus costs); thereafter it trails at ``trail_atr_mult`` times ATR behind the
most favourable close since the level-2 fill. The basket stop only ever
tightens — it never widens, and no filled leg carries a wider individual stop
than the current basket stop.

## Take profit
No fixed price target. Profit-taking is the giveback stop: the basket is
closed when open P&L falls to ``giveback_frac`` of the peak open basket P&L,
retaining (1 - ``giveback_frac``) of the best intraday run by construction.
A fixed-R target is deliberately absent: it would cap the right tail the
pyramid exists to capture and duplicates the trailing stop's role.

## Trailing logic (never-widening basket stop)
For a long basket (mirror for short): ``basket_stop = max(previous
basket_stop, blended_breakeven + be_buffer_atr x ATR, peak_close_since_L2 -
trail_atr_mult x ATR)`` evaluated on every bar close after level 2 fills;
before level 2 fills the basket stop is the level-1 reference stop. The
ratchet (max over history) is what makes the stop never-widening by
construction. After level 3 fills the trail continues behind the most
favourable close; the add and the stop ratchet never relax it.

## Giveback and basket-loss bounds
Peak open basket P&L (in R, 1R = ``risk_per_trade_pct`` of equity on the
level-1 reference stop) is tracked from basket open and refreshed on every
bar close before the giveback test, so a bar making a new peak cannot trigger
the giveback against itself. The giveback stop arms only once the peak is
strictly positive. The hard equity adverse bound (``basket_adverse_bound_pct``)
is the Family A ruin bound: it flattens the basket regardless of price levels
and is the emergency exit the joint-tail engine reads as ``max_basket_loss_pct``.

## Position sizing
Level 1 risks ``risk_per_trade_pct`` of equity at its reference stop
(RISK_FIXED in backtest, RISK_PERCENT live; family bound: never above 0.25%).
Levels 2 and 3 size at ``level2_size_mult`` and ``level3_size_mult`` of the
base size (Family A progression 1.0 / 0.75 / 0.5), so a fully built basket
carries 2.25 base legs and at most 5% margin. Aggregate basket exposure never
exceeds 2.25 base legs; one pyramid per symbol per day; at most
``max_positions_total`` concurrent baskets across the EA's symbol slots, so
worst-case planned stop risk across the EA is bounded by the daily and weekly
breakers even if every basket is fully built. Family-contract fixed values
(deliberately not free parameters): level weights 1.0 / 0.75 / 0.5, aggregate
2.25 legs, margin cap 5%, level cap 3; the emergency-exit bounds 0.5% adverse
and 50% giveback are upper bounds (the card may tighten via
``giveback_frac`` and ``basket_adverse_bound_pct``, never widen).

## Session rules
Entries (base legs) allowed only between ``session_start_hour_utc`` and
``session_end_hour_utc`` (UTC), and only after the opening range (the first
``breakout_window_bars`` session bars) has completed; mandatory flat by
``flatten_hour_utc``. Session hours are strategy inputs; the EA maps broker
time to UTC through the shared QM_DSTAware include (no hand-rolled DST).
No new basket on Friday after ``friday_cutoff_hour_utc``; no weekend carry.

## Filters
Volatility/shock filter (skip the day when the first session bar's range >
``shock_atr_mult`` * ATR; the pilot-measured 13:00 bar median is ~2.8x ATR on
the NDX-class proxy feed, so the floor defaults to 3.0 and only extreme shock
days are skipped). Spread filter (skip the entry when the current spread >
``spread_median_mult`` * the 20-day median spread). News blackout:
high-impact events (FOMC/NFP/CPI) inside ``news_blackout_minutes`` of an entry
or an add block the fill (fail-closed when the MT5 native calendar is
unavailable). Daily circuit breaker: stop trading for the day at
``daily_stop_pct`` day P&L; stop for the week at ``weekly_stop_pct`` week P&L.
No negative pyramiding, no martingale, no averaging into losers: adds require
open profit and a new favourable extreme by construction.

## Deterministic risk contract (Family A — carried for programme uniformity)
Positive pyramiding is NOT tail-amplifying under STRATEGY_ELIGIBILITY_V2 §9, so
no contract is required at intake; the complete Family A contract is carried
anyway per the programme doctrine (uniformity + the joint-tail engine needs
declared bounds for every sleeve it measures):

```json
{
  "schema": "qm.strategy-risk-contract/v1",
  "tail_amplifying": false,
  "mechanism_flags": ["positive_pyramiding"],
  "max_levels": 3,
  "sizing_progression": {"type": "custom", "multiplier": null, "notes": "per-level multipliers [1.0, 0.75, 0.5] of the initial leg; aggregate = 2.25 initial legs"},
  "max_open_positions": 3,
  "max_basket_exposure": "2.25",
  "max_gross_notional": "2.25",
  "max_margin_pct": 5.0,
  "max_basket_loss_pct": 0.5,
  "emergency_exit": {
    "type": "equity_stop",
    "equity_stop_pct": 0.5,
    "rule": "Flatten the whole basket when (a) open adverse excursion reaches 0.5% of account equity OR (b) open profit giveback reaches 50% of peak open basket profit, whichever occurs first. Stops only ever tighten, never widen."
  },
  "gap_sensitivity": "SESSION-FLAT: no overnight/weekend exposure by construction; gap tail removed by the flatten-hour rule (FTMO envelope). Sealed stress s01/s04/s05/s06/s08 still to be run by the governed pipeline.",
  "spread_slippage_sensitivity": "NOT_EVALUATED (Q06 HARSH-class pending)",
  "worst_historical_sequence": {"max_adverse_levels": "EVIDENCE_MISSING", "max_drawdown_pct": "EVIDENCE_MISSING", "evidence": "EVIDENCE_MISSING"},
  "stress_sequence": {"scenario": "s08_combined_worst at max_levels with basket fully built", "result_pct": "NOT_EVALUATED", "evidence": "EVIDENCE_MISSING"},
  "session_flat": true,
  "daily_breaker_pct": -1.0,
  "weekly_breaker_pct": -2.0
}
```

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the
live MT5 news calendar. No external feed.

## Timeframe
H1 for signals and basket management (an M15 execution variant, mirroring the
H-CW card, is allowed); no D1 or higher signals.

## Symbols
NDX, GDAXI, SP500 index CFDs (symbols are inputs, never code literals; one
input per symbol slot). No FX, no metals, no energy.

## Parameter ranges
- breakout_window_bars: 2 .. 4
- ema_period: 15 .. 30
- breakout_buffer_atr: 0.0 .. 0.05
- atr_period: 10 .. 20
- atr_stop_mult: 0.75 .. 1.25
- add2_trigger_atr: 1.0 .. 1.5
- add3_trigger_atr: 2.0 .. 3.0
- level2_size_mult: 0.75 .. 0.75
- level3_size_mult: 0.5 .. 0.5
- be_buffer_atr: 0.0 .. 0.1
- trail_atr_mult: 0.75 .. 1.25
- giveback_frac: 0.4 .. 0.5
- basket_adverse_bound_pct: 0.25 .. 0.5
- time_stop_bars: 4 .. 8
- risk_per_trade_pct: 0.20 .. 0.25
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 2.5 .. 3.5
- spread_median_mult: 1.25 .. 1.75
- session_start_hour_utc: 13 .. 14
- session_end_hour_utc: 16 .. 17
- flatten_hour_utc: 20 .. 21
- friday_cutoff_hour_utc: 17 .. 18
- max_positions_total: 1 .. 3
- news_blackout_minutes: 0 .. 120

## Expected frequency
At most one basket per day per symbol by construction. The deterministic
pilot fire count of these exact rules (NDX-class Dukascopy feed, 2018-2020
in-sample, computed output ``h_py_pilot.json``) recorded: 489 evaluated session
days (154 shock-skipped at 3.0x), 187 gross signals, 185 taken baskets, 6.4
baskets/month and ~6.4 active days/month over 29 months; exits 73 base stops,
37 giveback stops, 75 session-flat flattens; level 2 filled in 11.9% of
baskets, level 3 in 0% (the proxy feed never printed a second qualifying
extreme — the level-3 leg is therefore untested even at pilot level); raw
outcome PF(R) 1.26 at +0.12R/basket, average peak open basket profit +0.77R,
maximum +19.1R. These are honest pilot measurements used for density
calibration and feasibility only: they are IN-SAMPLE on one proxy feed with
zero costs, and the preregistered validation must treat them as motivation,
not evidence — the governed pipeline (filters, .DWX execution, Q00-Q17) is the
judge.
Expect roughly one basket per day per symbol on evaluated (non-shock) session
days, about 12-20 baskets per month across the three index symbols, with at
least 8 active days per month — the same density order as the H-CW shell it
reuses.

## Regime of failure
Trend exhaustion and clustered session reversals. Parabolic reversal
immediately after level 3 prints converts the largest aggregate position at
the worst prices — bounded by the breakeven-plus trail and the giveback stop,
but repeated giveback exits are death by sequence. Correlated index symbols
breaking out together concentrate the same-session giveback across baskets
(NDX/GDAXI/SP500 share the cash-session factor). Choppy range sessions
produce repeated small base-stop and giveback losses. The regime of failure
is exactly what the preregistered kill criteria measure.

## Invalidation conditions
Refuted if, out of sample, the bounded pyramid does not beat its own flat
base-leg baseline (H-CW shape) on expectancy or worst-day loss, or if the edge
depends on a single symbol or single period. Refuted at programme level if the
joint-tail protocol shows the family's worst days systematically coincide with
the passive book's or the H-CW/H-MR sleeves' worst days (hidden common mode —
the family is the tail carrier and must not join a multi-sleeve book).

## Falsification / kill criteria
Killed if:
1. Sealed OOS + Q06 HARSH-class evidence: expectancy after costs < +0.10R per
   basket or net profit factor < 1.20.
2. Simulated worst-day p95 of the built-out basket > 2.5% of equity at the
   0.25% reference base risk, or Monte-Carlo P(hit the 4% effective daily-loss
   budget within 60 days) > 2%.
3. More than 50% of pyramids are stopped at the giveback stop before level 2
   fills (the mechanism captures noise, not trends).
4. The giveback stop realizes more often than the profit-taking exits
   (trailing stop / session flat with positive basket P&L) across the sealed
   window with no regime explanation.
5. The joint-tail protocol (PORTFOLIO_TAIL_RISK_RESEARCH.md §4) fails against
   the H-CW/H-MR/passive-book streams — worst-day overlap beyond the
   independence baseline or materially positive lower-tail dependence — before
   any book claim.
6. H-CW-class gates: realized swap/rollover cost > 10% of gross P&L; more than
   half of the +-1-step parameter neighbourhood shows negative expectancy; any
   single month with < 8 active days.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk — the tail a built-out
basket fears most is removed by construction, not by stop placement. The
shock and spread filters and the live news filter fail closed; adds are
suspended inside the news blackout like entries. Q08 stress and Q11
full-history confirmation remain the judges before any book placement; the
Family A stress set (s01 gap x1, s04 spread x2, s05 spread x3+slippage, s06
news shock, s08 combined worst) must be run sealed before any FTMO claim.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop on a built-out basket),
a hard 0.5% equity basket bound plus a -1.0% daily / -2.0% weekly breaker
stack far inside the FTMO 5% daily and 10% total drawdown limits, and the
high-impact news blackout keeps FOMC/NFP/CPI windows closed. The -10.26% demo
breach was produced by overnight/swap tails on carried positions; the
session-flat envelope is precisely the defence, and the bounded pyramid adds
convex trend capture inside it rather than a new tail. As the aggressive
family admitted to FTMO evaluation at programme stage (Family A is FTMO-primary
per the programme), it stacks inside the 4% effective joint daily-loss budget
with the passive book — but only after the joint-tail protocol clears it
against the H-CW/H-MR streams.
