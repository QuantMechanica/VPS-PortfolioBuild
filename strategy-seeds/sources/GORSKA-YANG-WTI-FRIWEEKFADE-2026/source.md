---
source_id: GORSKA-YANG-WTI-FRIWEEKFADE-2026
title: WTI Friday premium after an exact Monday-through-Thursday loss
publisher: Quantitative Methods in Economics / SSRN
source_type: academic_composite_lineage
status: approved_source_complete
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
approved_by: "OWNER commodity/energy portfolio mission 2026-08-17"
approved_at: 2026-08-17
source_approval: decisions/2026-08-17_wti_friday_week_pullback_source_approval.md
strategy_ids:
  - GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01
parent_sources:
  - GORSKA-WTI-CAL-2015
  - YANG-COMM-REVERSAL-2017
---

# WTI Friday / Exact-Week Pullback Source Packet

## Source Identity And Read Boundary

This bounded packet joins two governed academic source records. Both parent
records were read completely before this packet and its approval were written:

1. Anna Gorska and Malgorzata Krawiec (2015), "Calendar Effects in the Market
   of Crude Oil," *Quantitative Methods in Economics* 16(4). The complete
   repository extraction at
   `strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md` identifies Friday as
   the strongest positive average WTI weekday in the paper's sample and
   preserves the primary PDF URL.
2. Liu Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. The complete repository
   extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` supplies only the
   structural fixed-horizon commodity-reversal lineage and records the
   working-paper URL and its existing energy translations.

Gorska and Krawiec supply only the positive Friday direction. Yang, Goncu,
and Pantelous supply only the broader commodity-reversal hypothesis. Neither
source tests an exact Monday-open through Thursday-close WTI formation, a
Friday-only Darwinex trade, the conjunction of those two states, a continuous
CFD, broker-label normalization, fixed-dollar risk, an ATR hard stop, or the
V5 Friday-close implementation.

No source return, coefficient, significance level, cost, drawdown, trade
count, WTI-only reversal result, CFD equivalence, correlation, or portfolio
result transfers to this candidate. The short formation horizon and source
conjunction are transparent QM falsification choices.

## Bounded Mechanization

`GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01` is one direct-WTI, low-frequency
calendar/reversal package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- decide only at the first executable tick of a genuine broker Friday, no
  later than 180 minutes after that session's D1 open;
- normalize energy D1 labels only by one uniform convention: native same-day
  labels or a uniform `+1` calendar-day offset inferred from the current bar;
- require the current Friday plus exact immediately completed Thursday,
  Wednesday, Tuesday, and Monday sessions, with no holiday substitution,
  missing-day compression, or earlier-week backfill;
- persist the Friday `yyyymmdd` attempt before history, signal, news, spread,
  quote, ATR, sizing, or order gates, so a failure or restart cannot retry;
- compute the only signal as
  `formation_return = ln(ThursdayClose / MondayOpen)` from those completed
  sessions;
- BUY WTI only when `formation_return < 0`; exact zero, a positive formation,
  invalid endpoints, or broken calendar identity consumes the Friday flat;
- use no magnitude threshold and never scale size by return magnitude;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.0 * ATR(20,D1)` server-side hard stop, a 1,500-point spread ceiling, and
  no take-profit;
- flatten through the framework Friday-close guard at broker hour 21, with
  first-later-D1 and three-calendar-day repairs if the normal cutoff is missed;
  and
- never retry, scale in, pyramid, grid, martingale, hedge, or read an external
  runtime source.

The Monday-open endpoint deliberately captures the completed four-session
path into Friday. It is not a Thursday-only shock, a previous full-week
return, a prior-month state, a slow trend state, or a weekend gap.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: the packet identifies the
  named authors and durable primary records for an academic WTI calendar
  paper and a commodity-reversal working paper. The untested conjunction,
  short-horizon translation, working-paper status, multiple-testing risk,
  and possible post-sample decay are explicit.
- R2 `PASS`: carrier, period, normalized calendar sequence, signal endpoints,
  return orientation, strict negative condition, long-only mapping, attempt,
  grace, risk, stop, spread, Friday cutoff, and stale repairs are exact.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC plus
  native MT5 broker time, quotes, ATR, positions, deals, and terminal state
  provide every runtime input. The same-day versus uniform `+1` energy-label
  convention remains a falsifiable carrier risk.
- R4 `PASS`: deterministic calendar, logarithm, comparison, ATR risk distance,
  and native execution state only; no trained output, banned signal indicator,
  external feed, grid, martingale, scale-in, hedge, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,538 EA-registry rows and 625
root card files. It found no exact slug or strategy-ID identity and no fuzzy
mechanic match. Manual family review returned
`CLEAN_WTI_EXACT_MONDAY_THURSDAY_LOSS_FRIDAY_BOUNCE_AFTER_FAMILY_REVIEW`:

- `QM5_12753_wti-thu-pb-fri-bounce` requires the single Thursday
  close-to-close return to be at most a fixed negative threshold. This packet
  uses no magnitude threshold and reads the distinct Monday-open through
  Thursday-close formation. It can admit a positive Thursday inside a losing
  four-session path and reject a negative Thursday inside a winning path.
- `QM5_20117_wti-fri-lagrev` shorts after a `4.5%` Thursday surge, the
  opposite direction and a one-session threshold state.
- `QM5_12597_wti-fri-prem` buys every eligible Friday unconditionally.
- `QM5_20145_wti-fri-trend` and `QM5_20172_wti-fri-bear` condition each
  Friday on the sign of a completed 252-D1 return, not the current exact week.
- `QM5_41026_wti-1fri-rev1` trades only the first Friday of a month after a
  negative completed calendar month.
- `QM5_41019` through `QM5_41022` form prior or earlier-week momentum states
  and enter before Friday; they do not fade the current Monday-Thursday path
  for a single Friday session.
- `QM5_20226_wti-seas-dow` and `QM5_20029_wti-monfri-daily` use unconditional
  or fixed-season weekday maps without the four-session pullback.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback above a slow average, not a WTI calendar/reversal interaction.

The exact five-session identity, Monday-open and Thursday-close endpoints,
strict negative-only state, long Friday direction, one-attempt clock, and
same-session lifecycle are jointly load-bearing. A failed result may not be
rescued by changing the weekday, formation endpoints, sign, threshold,
direction, stop, or hold.

## Frequency, Kill, And Safety Boundary

An ordinary calendar year offers roughly 45-50 exact Monday-through-Friday
weeks after holidays. If the four-session return sign is approximately
balanced, the locked condition implies roughly 20-25 decisions per year
before execution gates. This is a design-density reference, not market
evidence. Q02 must retire on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong weekday or
endpoints, late/repeated entry, current-Friday price leakage into the signal,
wrong side, missing hard stop, wrong Friday lifecycle, nondeterminism, or an
unusable energy-label convention.

This packet authorizes one V5 Strategy Card, deterministic registry
allocation, one branch-only non-live build, strict Q01 validation, one
`RISK_FIXED` backtest preset, and one paced target-only Q02 enqueue if the
governed tester and CPU ceilings permit. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate edit, a decorrelation claim, or a correlation waiver. Q09
alone may establish realized portfolio correlation.

