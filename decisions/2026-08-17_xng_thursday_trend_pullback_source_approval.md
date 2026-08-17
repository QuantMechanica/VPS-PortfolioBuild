# XNG Standard-Thursday Counter-Move / Slow-Trend Re-entry — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01 validation,
and one paced target-only Q02 enqueue if the tester ceiling permits. This
decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests a genuinely different
commodity/energy sleeve, explicitly permits a second XNG edge only when its
logic differs from `QM5_12567`, requires reputable sources and `RISK_FIXED`
backtests, and excludes the portfolio gate, `T_Live`, AutoTrading, and live
manifests.

## Candidate Identity

- proposed slug: `xng-thu-trend-pb`
- proposed strategy ID: `EIA-MOP-XNG-THUTRENDPB-2026_S01`
- source ID: `EIA-MOP-XNG-THUTRENDPB-2026`
- carrier: exact `XNGUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Friday tick after an exact standard
  Thursday
- signal: strict sign opposition between the completed Thursday close-to-close
  return and a separate 252-session trend ending at Wednesday close
- lifecycle: trade the slow-trend sign and close at the next D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded composite packet at
`strategy-seeds/sources/EIA-MOP-XNG-THUTRENDPB-2026/source.md` was read
completely before this decision. Its governed parents were also read within
their documented complete bounds:

1. The official U.S. Energy Information Administration WNGSR packet at
   `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md` supplies
   the recurring ordinary-Thursday natural-gas information clock and
   holiday-shift caveat.
2. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, through the complete
   governed 23-page review and retrieval hash at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supplies own-instrument
   twelve-month trend lineage and explicitly includes natural gas.

EIA does not test a trading rule. The JFE paper does not test this weekly
counter-move conjunction or establish an XNG-specific result for it. No
performance, significance, density, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Friday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1` energy D1 label
   convention. Require current Friday plus exact immediately completed
   Thursday, Wednesday, and Tuesday sessions; never substitute a missing day.
3. Persist the broker-Friday attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry or backfill it.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `event_return = ln(ThursdayClose / WednesdayClose)`.
6. Compute `slow_trend = ln(WednesdayClose / Close252SessionsBeforeWednesday)`.
   Thursday may not enter the slow state.
7. Require both returns finite, nonzero, and strictly opposite in sign. A
   positive slow trend buys XNG after a negative Thursday; a negative slow
   trend sells XNG after a positive Thursday. Agreement or equality consumes
   Friday flat. Magnitude never scales size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.5 * ATR(20,D1)` hard stop, a 3,000-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Monday open. Framework
   Friday close is disabled for the weekend-bearing one-D1 hold; a four-day
   guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official government event lineage
  and complete-read peer-reviewed natural-gas trend lineage, with the untested
  conjunction and CFD translation explicit.
- R2 `PASS`: calendar, endpoints, separate trend window, opposition,
  slow-trend direction, attempt, timing, risk, stop, spread, and exit are
  locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC and native
  MT5 state supply every runtime input; carrier label normalization remains a
  disclosed falsification risk.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,534 registry rows and 625 root card files. It
found no exact identity and surfaced three lexical/source-family fuzzy matches:
`wti-dom-trend`, `wti-lr-trend`, and `xng-lr-trend`. Manual review separates all
three and the material mechanic neighbors:

- `QM5_41046_wti-wed-trend-pb` is the same experiment family but a distinct
  WTI carrier/event clock and Thursday-to-Friday lifecycle. This candidate is
  XNG around Thursday storage-event time and owns Friday-to-Monday.
- `QM5_20163_xng-thu-trend` enters before Thursday from a negative slow state;
  this candidate waits for the completed Thursday counter-move and is
  symmetric.
- `QM5_41043_xng-thu-flow-agree` and `QM5_41044_xng-thu-flow-fade` compare
  close-to-open and open-to-close components; this candidate ignores those
  components and compares the whole event return with a non-overlapping slow
  trend.
- `QM5_20239_wti-pulltrend` is monthly WTI with a monthly hold.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` are M30 release-window systems.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_COUNTER_MOVE_PRE_EVENT_TREND_REENTRY_AFTER_EXACT_AND_MANUAL_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than eight per
year, nonpositive governed economics, wrong calendar or endpoints, Thursday
leakage into the slow state, non-opposed signs, wrong direction, late or
repeated entry, wrong next-D1 lifecycle, nondeterminism, invalid risk mode, or
an unusable standard-Thursday proxy. Q09 alone may establish realized book
correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the exact-path capacity check is below the governed tester ceiling. At the
ceiling, stop before queue mutation and report the handoff.
