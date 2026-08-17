# WTI Standard-Wednesday Strict Flow-Agreement Continuation — Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA
ID and magic allocation, one branch-only non-live build, strict Q01 validation,
and one paced target-only Q02 enqueue if the tester ceiling permits. This
decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wed-flow-agree`
- proposed strategy ID: `EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026_S01`
- source ID: `EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable broker-Thursday tick after exact completed
  Monday, Tuesday, and Wednesday sessions
- price state: completed Wednesday close-to-open and open-to-close flows
- lifecycle: require strict component sign agreement, follow the completed
  Wednesday total, and close at the next D1 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded packet at
`strategy-seeds/sources/EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026/source.md` was
read completely before this decision. Its governed parents were also read
within their documented bounds:

1. The approved U.S. Energy Information Administration WPSR packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md` supplies the
   ordinary Wednesday crude-oil information clock and holiday-shift caveat.
2. Williams (1999), *Long-Term Secrets to Short-Term Trading*, through
   `strategy-seeds/sources/SRC03/source.md` and the complete bounded
   `raw/probe_pp15-30.txt`, defines close-to-open and open-to-close price flows
   and their separate accumulation.
3. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, through the governed
   complete-paper receipt at `strategy-seeds/sources/MOP-TSMOM-2012/source.md`,
   supplies broad own-return continuation lineage across liquid futures,
   including WTI.

No source tests the exact event-time/decomposition/continuation conjunction.
MOP's tested horizons are longer than one D1 session. No performance,
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
5. Compute `overnight_flow = ln(WednesdayOpen / TuesdayClose)` and
   `session_flow = ln(WednesdayClose / WednesdayOpen)` from completed prices.
6. Require both components nonzero and strictly same-sign. Reconcile their sum
   to `ln(WednesdayClose / TuesdayClose)` within `1e-10`.
7. Follow the completed Wednesday total: positive buys WTI and negative sells
   WTI. Opposition, exact zero, invalid arithmetic, broken calendar identity,
   or failed reconciliation consumes Thursday flat. Magnitude never scales
   size.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target.
9. Close at the first later D1 boundary, ordinarily Friday open. Framework
   Friday close at broker hour 21 remains a fail-safe; a three-day guard
   repairs stale exposure.
10. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
    runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete Tier-A Williams extraction, and complete-paper peer-reviewed JFE
  continuation lineage. The untested conjunction and horizon mismatch are
  explicit.
- R2 `PASS`: calendar, endpoints, agreement, reconciliation, continuation
  direction, attempt state, timing, risk, stop, spread, and exit are locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native MT5 state supply every
  runtime input.
- R4 `PASS`: deterministic calendar and return arithmetic only; no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,529 registry rows and 625 flat card files. It
found no exact identity and correctly surfaced fuzzy relatives
`QM5_41029_wti-flow-agree` and `QM5_41034_wti-mflow-agree` for manual review.

- `QM5_41029` forms over an exact full week, enters Monday, and holds to
  Friday; this candidate forms from one standard Wednesday, enters Thursday,
  and exits next D1.
- `QM5_41034` forms and holds over broker months; this candidate owns one D1
  interval around a weekly information clock.
- `QM5_41041` requires component opposition plus session dominance and fades
  the completed total; this candidate requires strict agreement and follows
  the total.
- `QM5_20154` is long-only under a completed 252-D1 positive trend; this
  candidate is symmetric and has no slow trend state.
- `QM5_41024` trades only the first Wednesday of a month from a completed-
  month sign; this candidate evaluates every eligible Thursday from the
  immediately completed Wednesday decomposition.
- `QM5_12567` is a long-only cumulative-RSI2 pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than
five/year, nonpositive governed economics, wrong weekday identity or
endpoints, component opposition, wrong continuation direction, failed
reconciliation, late or repeated entry, wrong lifecycle, nondeterminism,
invalid risk mode, or an unusable standard-Wednesday proxy. Source-to-rule
distance, futures/CFD basis, holiday shifts, financing, gaps, and later book
correlation are first-order risks. Q09 alone may establish realized
correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once only if the exact-path capacity
check is below the governed tester ceiling. At the ceiling, stop before queue
mutation and report the handoff.
