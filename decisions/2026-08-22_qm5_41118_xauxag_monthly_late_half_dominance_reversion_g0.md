# QM5_41118 XAU/XAG Completed-Month Late-Half Dominance Reversion - G0

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the committed source approval `3da399186`
and the non-live safety restrictions recorded there.

## Identity

- EA ID: `QM5_41118`
- slug: `xauxag-mlatehalf-dom-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026_S01`
- source ID: `SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026`
- logical symbol: `QM5_41118_XAU_XAG_MLATEHALF_DOM_RV_D1`
- host and slot zero: exact `XAUUSD.DWX`, D1, planned magic `411180000`
- companion and slot one: exact `XAGUSD.DWX`, D1, planned magic `411180001`

The deterministic EA-ID reservation is commit `ad481dc84`. The approved card
is
`strategy-seeds/cards/approved/QM5_41118_xauxag-mlatehalf-dom-rv_card.md`.

## Source Gate

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026/source.md`,
committed at `af92247db`. Its governed parents were read completely before
source approval:

- `SCHWEIKERT-XAUXAG-RATIO-2026`, SHA-256
  `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
  preserving Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
  DOI `10.1016/j.jbankfin.2017.11.010`, and supporting Yaya, Vo, and
  Olayinka (2021), *Resources Policy* 72, 102045, DOI
  `10.1016/j.resourpol.2021.102045`.
- `CME-GSR-SPREAD-2025`, SHA-256
  `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
  preserving the CME gold/silver ratio and intermarket-spread carrier.

The sources support testing a state-dependent gold/silver relationship and an
intermarket ratio carrier. They do not supply the within-month late-half
dominance gate, the contrarian one-month hold, CFD equivalence, equal-notional
fixed-risk execution, density, economics, neutrality, or decorrelation. Those
are disclosed QM hypotheses.

## Approved Mechanic

At the first tradable exact synchronized XAU/XAG D1 boundary of a new broker
month, within 180 elapsed minutes of the raw host-bar open, reconstruct the
two immediately preceding consecutive completed calendar months. Each month
must contain 17 through 23 unique timestamp-identical close pairs.

Let `P` be the parent month's chronological final synchronized log ratio and
let `Q[0]...Q[n-1]` be every chronological ratio in the immediately completed
month. Set:

```text
h     = floor(n / 2)
early = Q[h-1] - P
late  = Q[n-1] - Q[h-1]
```

Enter only when `abs(late) > abs(early)`. A positive late half opens SELL XAU
and BUY XAG; a negative late half opens BUY XAU and SELL XAG. Equality, zero,
invalid arithmetic, malformed/asynchronous history, current-month leakage, or
non-dominance consumes the month flat. The shared midpoint is an anchor rather
than a duplicated return, so the halves exhaust all `n` adjacent relative
returns. Early-half sign and full-month endpoint sign never change the map.

Persist the decision `yyyymm` before history, signal, spread, quote, ATR,
sizing, news, or order gates. Use one equal-absolute-notional opposite-leg
package with combined normalized hard-stop risk at or below
`RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen `3.5 * ATR(20,D1)` hard stops,
no targets, and at most 20-percent notional mismatch. Flatten both legs on the
first later broker month, with forty calendar days as stale repair only.

## Non-Duplicate Finding

Before allocation, the canonical checker used the exact slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,615 registry identities, 1,286 cards, and 45 Wiki nodes and returned
`CLEAN` with no exact or fuzzy match. Evidence:
`artifacts/qm5_xauxag_mlatehalf_dom_rv_preallocation_dedup_20260822.json`.

After allocation, the same checker scanned 4,616 registry identities, 1,286
cards, and 45 Wiki nodes. The only exact hits were the newly reserved
`QM5_41118` slug and strategy ID. They are expected self-hits, not a second
implementation. Evidence:
`artifacts/qm5_41118_xauxag_mlatehalf_dom_rv_postallocation_dedup_20260822.json`.

Manual semantic review found no foreign duplicate:

- `QM5_41113` requires two-half sign agreement and ignores magnitude;
  QM5_41118 requires late-half magnitude dominance and permits opposed signs.
- `QM5_41116` votes three magnitude-blind blocks; QM5_41118 compares two
  exhaustive halves by magnitude and has no vote.
- `QM5_41112` counts individual daily relative-return signs and requires
  endpoint agreement; QM5_41118 does neither.
- `QM5_41117` is direct-WTI late-half continuation; QM5_41118 computes a
  synchronized intermetal relative path, fades the late sign, and owns two
  opposite equal-notional legs.
- `QM5_20260` votes one-, three-, and twelve-month cross-sectional ranks;
  QM5_41118 partitions only one completed month.
- rolling gold/silver ratio/residual cards estimate a center, regression,
  scale, score, or tail; QM5_41118 estimates none.
- certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_LATE_HALF_ABSOLUTE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## R1-R4 Findings

- R1 `PASS_WITH_LATE_HALF_DOMINANCE_TRANSLATION_RISK`: named peer-reviewed
  DOI and official-exchange lineage, complete governed records, durable hashes,
  and explicit disclosure that the path gate is untested.
- R2 `PASS`: clock, synchronization, consecutive months, session bounds,
  parent anchor, split, exhaustive blocks, strict magnitude/sign state,
  equality/zero handling, attempt, package sides, risk, atomicity, and
  lifecycle are deterministic.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  XAU/XAG D1 histories and MT5 state supply all runtime data. Q02 owns holiday
  attrition, cadence, costs, fills, financing, and CFD-basis sufficiency.
- R4 `PASS`: timestamp and completed-price arithmetic plus framework state
  only; no trained logic, banned signal, external runtime feed, grid,
  martingale, scale-in, or pyramid.

The required card schema and prohibited-method lint passes with no missing
sections and no ML hits.

## Build Authorization

Development may build exactly the approved card after creating the EA
directory and allocating two active magic rows in governed order. The build
must preserve:

- exact synchronized XAU/XAG D1 carrier, slots, and registered magics;
- two consecutive 17-to-23-session completed calendar months;
- parent-final ratio anchor and the `floor(n/2)` split;
- exhaustive non-overlapping early and late relative-return blocks;
- strict late-half absolute dominance with contrarian late-sign sides;
- equality, zero, non-dominance, and malformed history as consumed flat;
- the persisted one-attempt rule;
- one aggregate fixed-risk equal-notional package with two hard stops; and
- atomic repair plus exact next-month closure.

Q01 requires a deterministic reference suite, card/source alignment,
`basket_manifest.json`, resolver identity, one canonical fixed-risk logical
basket set, strict compile, zero errors and warnings, non-empty EX5, and
build-check PASS. Q02 may receive exactly one paced work item only after Q01
passes and a fresh CPU/capacity check permits it. A blocked compile or CPU
ceiling must be recorded and left for governed continuation; it does not
authorize an ad-hoc tester or terminal action.

## Falsification

Q02 retires on zero completed packages, fewer than five packages per full
post-warm-up year, nonpositive governed economics, invalid synchronization or
month membership, wrong split, skipped or duplicated relative returns, wrong
comparison, equality/zero drift, wrong package sides, duplicate attempts,
invalid aggregate risk, missing stops, orphan exposure, lifecycle drift, or
nondeterminism. No post-result rescue through split, comparison, side, hold,
session-bound, agreement condition, or added filter is authorized.

## Portfolio And Safety Boundary

Opposite equal-notional legs are designed to suppress common outright-metal
direction, not to prove beta, factor, volatility, market, or portfolio
neutrality. Q09 alone owns realized correlation with the certified
XAU/SP500/NDX/XNG book.

This approval permits research, allocation, a branch-only non-live build,
strict Q01, and one paced Q02 enqueue if capacity permits. It authorizes no
manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest mutation, portfolio-gate change,
portfolio admission, decorrelation claim, correlation waiver, or live use.
