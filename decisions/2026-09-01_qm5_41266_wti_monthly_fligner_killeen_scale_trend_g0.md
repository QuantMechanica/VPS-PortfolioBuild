# QM5_41266 WTI Monthly Fligner-Killeen Scale Trend - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41266_wti-mfk-scale-tr`
- Strategy ID: `AI-CODEX-WTI-MFK-SCALE-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41266_wti-mfk-scale-tr_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-WTI-MFK-SCALE-20260901/source.md`
- Source approval commit: `b13f35117b`
- Identity reservation commit: `4d2b056b46`
- Intended magic after governed allocation: `412660000`

## Decision

Approve one branch-only non-live build of the locked WTI monthly Fligner-
Killeen median-centered normal-score scale-expansion continuation rule,
followed by strict Q01 and one paced Q02 enqueue if CPU admission permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source And R1

`APPROVED_WITH_EXPLICIT_SYNTHESIS_AND_METHOD_ACCESS_RISK`. The evidence
contains a complete governed read of the peer-reviewed WTI carrier paper, a
named peer-reviewed Fligner-Killeen method record with an explicit full-body
access boundary, and complete official signed-tag-pinned SciPy documentation
and source for the exact arithmetic.

The sources support the WTI monthly continuation carrier and the group-
median absolute-deviation, pooled-midrank, normal-score scale construction
only. Fixed blocks, recent-only scale direction, six-month return side, CFD
translation, activity boundary, execution, risk, and lifecycle are pre-result
QM synthesis.

## R2 Mechanical Contract

`APPROVED`. The card locks:

1. exact `XTIUSD.DWX` D1 carrier and one consumed attempt per broker month;
2. thirteen consecutive completed month-end closes and twelve adjacent log
   returns, excluding the current month;
3. fixed old/recent blocks of six and each block's even median;
4. twelve group-median absolute deviations, anchored relative-tolerance tie
   runs, pooled midranks, and exact rank-sum 78 invariant;
5. the 23 exact integer/half-integer normal-score constants for
   `Phi^-1(0.5+R/26)`;
6. exact group means, pooled score variance with divisor eleven, two-group
   statistic, denominator floor `1e-18`, and finite arithmetic;
7. strict recent-above-old score mean plus recent six-return cumulative sign;
8. one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` stop, spread cap,
   monthly exit, and forty-day stale repair; and
9. both news axes, legacy news mode, and Friday close OFF.

There is no optimization surface, fitted coefficient, chi-square critical
value, p-value, statistic-strength sizing, intramonth retry, external runtime
input, target, trail, grid, martingale, or scale-in.

## R3 Data

`APPROVED_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native
`XTIUSD.DWX` D1 history and MT5-native state provide every signal and
execution input. Q02 must expose roll/basis, financing, spread, gap, month-
label, and history-window failures.

## R4 Prohibited Logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, absolute values, fixed table lookup, finite arithmetic,
comparisons, ATR risk, quotes, orders, positions, deals, and terminal state.
It has no trained signal, prohibited signal indicator, random runtime
sampling, or external runtime feed.

## Pre-Result Activity Prior

Equal-block label swapping places 462 of the 924 distinct-rank allocations in
the recent-score-above-old state and 462 below. This implies approximately
six qualifying states per twelve monthly attempts before ties, neutral side,
data, and execution gates. It is not an empirical frequency or alpha claim.
Retire below five completed positions in every full post-warm-up year.

## Dedup Adjudication

The corrected-root receipt scanned 4,765 identities, 1,402 cards, and 45 Wiki
nodes, finding no exact identity and one fuzzy `QM5_41261` match. Ansari-
Bradley ranks raw returns with symmetric end scores and an exact 924-label
tail. This card first centers each fixed block separately, ranks pooled
absolute deviations with midranks, applies normal scores, and has no
permutation tail. Fixed fixtures prove both decision-disagreement directions.
The permutation-MAD neighbor recomputes group scales for every relabeling;
this card preserves observed centers and one pooled score path.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_GROUP_MEDIAN_ABSOLUTE_DEVIATION_POOLED_MIDRANK_NORMAL_SCORE_FLIGNER_KILLEEN_RECENT_SCALE_EXPANSION_CUMULATIVE_RETURN_CONTINUATION`.

## Build Order

1. Create `framework/EAs/QM5_41266_wti-mfk-scale-tr/` and copy the approved
   card into `docs/strategy_card.md`.
2. Allocate active magic slot 0 only, regenerate the resolver, and verify the
   row survives.
3. Implement only the approved four-module behavior and exact reference
   fixtures.
4. Create exactly one `XTIUSD.DWX` D1 `RISK_FIXED` backtest setfile.
5. Compile through governed Q01, require zero compile errors/warnings and all
   static/reference checks, then enqueue exactly one Q02 row if CPU admission
   permits.

## Safety Boundary

Forbidden: manual tester launch, optimization, portfolio-gate mutation,
correlation waiver, portfolio admission, live/demo/shadow/stress preset,
`T_Live`, AutoTrading, deploy/live manifest, or terminal control.
