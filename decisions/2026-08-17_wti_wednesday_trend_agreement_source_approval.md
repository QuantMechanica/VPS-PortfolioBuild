# WTI Standard-Wednesday Event / Slow-Trend Agreement — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01 validation,
and one paced target-only Q02 enqueue if the tester ceiling permits. This
decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests a genuinely different
commodity/energy sleeve, names structural low-frequency WTI trend/seasonality
as an eligible lane, requires reputable sources and `RISK_FIXED` backtests, and
excludes the portfolio gate, `T_Live`, AutoTrading, and live manifests.

## Candidate Identity

- proposed slug: `wti-wed-trend-agree`
- proposed strategy ID: `EIA-MOP-WTI-WEDTRENDAGREE-2026_S01`
- source ID: `EIA-MOP-WTI-WEDTRENDAGREE-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Thursday tick after an exact
  standard Wednesday
- signal: strict sign agreement between the completed Wednesday close-to-close
  return and a separate 252-session trend ending at Tuesday close
- lifecycle: follow the common sign and close at the next D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded composite packet at
`strategy-seeds/sources/EIA-MOP-WTI-WEDTRENDAGREE-2026/source.md` was read
completely before this decision. Its governed parents were also read within
their documented complete bounds:

1. The official U.S. Energy Information Administration WPSR packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-AFTERSHOCK-2026/source.md` supplies the
   recurring ordinary-Wednesday petroleum information clock and holiday-shift
   caveat.
2. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, through the complete
   governed 23-page review and retrieval hash at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supplies own-instrument
   twelve-month trend lineage and explicitly includes WTI.

EIA does not test a trading rule. The JFE paper does not test this weekly event
conjunction or establish a WTI-specific result for it. No performance,
significance, density, cost, drawdown, CFD equivalence, decorrelation, or
portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Thursday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1` energy D1 label
   convention. Require current Thursday plus exact immediately completed
   Wednesday, Tuesday, and Monday sessions; never substitute a missing day.
3. Persist the broker-Thursday attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `event_return = ln(WednesdayClose / TuesdayClose)`.
6. Compute `slow_trend = ln(TuesdayClose / Close252SessionsBeforeTuesday)`.
   Wednesday may not enter the slow state.
7. Require both returns finite, nonzero, and strictly equal in sign. Positive
   agreement buys WTI; negative agreement sells WTI. Disagreement or equality
   consumes Thursday flat. Magnitude never scales size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Friday open. Framework
   Friday close remains enabled as a fail-safe; a three-day guard repairs stale
   exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official government event lineage
  and complete-read peer-reviewed WTI trend lineage, with the untested
  conjunction and CFD translation explicit.
- R2 `PASS`: calendar, endpoints, separate trend window, agreement, direction,
  attempt, timing, risk, stop, spread, and exit are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC and native
  MT5 state supply every runtime input; carrier label normalization remains a
  disclosed falsification risk.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,532 registry rows and 625 root card files. It
returned `CLEAN` with no exact or fuzzy identity. Manual family review fixes
the load-bearing boundaries:

- `QM5_41042_wti-wed-flow-agree` compares two components inside the completed
  Wednesday; this candidate compares the whole event-day return with a
  non-overlapping pre-event 252-session trend.
- `QM5_41041_wti-wed-flow-fade` requires opposed intraday components and fades
  the completed event day; this candidate requires cross-horizon agreement and
  continues it.
- `QM5_20154_wti-wed-trend` enters before Wednesday and owns the event; this
  candidate waits for the completed event bar and enters Thursday.
- `QM5_12590_eia-wti-aftershock` gates on event-day range expansion, not a
  separate slow trend.
- `QM5_20133/20134` use M30 release-sequence price patterns inside Wednesday.
- `QM5_12567_cum-rsi2-commodity` is a long-only oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_COMPLETED_EVENT_RETURN_AND_PRE_EVENT_TWELVE_MONTH_TREND_AGREEMENT_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than eight per
year, nonpositive governed economics, wrong calendar or endpoints, Wednesday
leakage into the slow state, sign disagreement, wrong direction, late or
repeated entry, wrong next-D1 lifecycle, nondeterminism, invalid risk mode, or
an unusable standard-Wednesday proxy. Q09 alone may establish realized book
correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the exact-path capacity check is below the governed tester ceiling. At the
ceiling, stop before queue mutation and report the handoff.
