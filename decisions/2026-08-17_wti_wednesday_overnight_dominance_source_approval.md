# WTI Standard-Wednesday Overnight-Dominant Flow — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester ceiling
permits. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wed-overnight-dom`
- proposed strategy ID:
  `EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026_S01`
- source ID: `EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Thursday tick after exact completed
  Monday, Tuesday, and standard Wednesday sessions
- price state: completed Wednesday close-to-open and open-to-close log flows
- lifecycle: require strict component opposition and strict overnight
  dominance, follow the reconciled completed-Wednesday direction, and close at
  the first later D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded composite packet at
`strategy-seeds/sources/EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026/source.md` was
read completely before this decision. Its governed parents were also read
within their documented complete bounds:

1. The official EIA WPSR packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md` supplies the
   ordinary Wednesday petroleum-information clock and holiday-shift caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   `raw/probe_pp15-30.txt`, defines close-to-open and open-to-close price
   flows, their separate accumulation, and their divergence/crossing lineage.
3. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, through the complete
   governed paper receipt at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supplies broad
   own-return continuation lineage and explicitly includes WTI.

No source tests the exact event/decomposition/dominance/continuation
conjunction. No performance, significance, density, cost, drawdown, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Thursday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed same-day or one uniform `+1` energy D1 label
   convention. Require current Thursday plus exact immediately completed
   Wednesday, Tuesday, and Monday sessions; never substitute a missing day.
3. Persist the broker-Thursday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry or backfill.
4. Require first observation within 180 minutes of executable D1 open.
5. Compute `overnight_flow = ln(WednesdayOpen / TuesdayClose)` and
   `session_flow = ln(WednesdayClose / WednesdayOpen)` from completed prices.
6. Require both components nonzero and strictly opposite in sign. Require
   `abs(overnight_flow) > abs(session_flow)` and reconcile their sum to
   `ln(WednesdayClose / TuesdayClose)` within `1e-10`.
7. Follow the completed total, which necessarily retains the overnight sign:
   positive buys WTI and negative sells WTI. Agreement, equality, exact zero,
   invalid arithmetic, broken calendar identity, or failed reconciliation
   consumes Thursday flat. Magnitude never scales size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Friday open. Framework
   Friday close remains enabled at broker hour 21 as a fail-safe; a three-day
   guard repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete Tier-A Williams decomposition, and complete-read peer-reviewed WTI
  continuation lineage, with the untested conjunction and horizon mismatch
  explicit.
- R2 `PASS`: calendar, endpoints, opposition, overnight dominance,
  reconciliation, continuation side, attempt, timing, risk, stop, spread, and
  exit are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XTIUSD.DWX` D1 OHLC and
  native MT5 state supply every runtime input; carrier label normalization
  remains a disclosed falsification risk.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,536 registry rows and 625 root card files. It
returned `CLEAN` with no exact or fuzzy identity. Manual family review fixes
the load-bearing boundaries:

- `QM5_41041_wti-wed-flow-fade` requires strict **session** dominance and
  fades the completed total; this candidate requires the disjoint strict
  **overnight**-dominant state and follows the completed total.
- `QM5_41042_wti-wed-flow-agree` admits only same-sign components; this
  candidate admits only strict opposition.
- `QM5_41033` and `QM5_41036` apply flow-dominance logic to full weeks and
  months with different clocks and lifecycles.
- `QM5_12784_progo-xti` compares smoothed fourteen-day flow lines and uses
  crossover exits; this candidate uses one unsmoothed event session and a
  next-D1 exit.
- `QM5_41045` and `QM5_41046` compare a whole Wednesday return with a separate
  slow trend and do not inspect its overnight/session components.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_OPPOSED_FLOW_STRICT_OVERNIGHT_DOMINANCE_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 retires on zero trades, fewer than five positions
per year, nonpositive governed economics, wrong session identity or
endpoints, component agreement, absent strict overnight dominance, wrong
continuation side, failed reconciliation, late or repeated entry, wrong
lifecycle, invalid risk mode, nondeterminism, or an unusable standard-
Wednesday proxy. No weak result may be rescued by accepting equality, changing
dominance, reversing direction, adding a magnitude threshold, changing the
weekday, or extending the hold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path tester
count is below the governed ceiling. If the ceiling is binding, stop before
queue mutation and record a non-live handoff.
