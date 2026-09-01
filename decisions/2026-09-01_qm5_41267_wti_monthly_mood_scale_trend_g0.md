# QM5_41267 WTI Monthly Mood Squared-Rank Scale Trend - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41267_wti-mmood-scale-tr`
- Strategy ID: `AI-CODEX-WTI-MMOOD-SCALE-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41267_wti-mmood-scale-tr_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-WTI-MMOOD-SCALE-20260901/source.md`
- Source approval commit: `6ef372bc80`
- Identity reservation commit: `33afb9fedb`
- Intended magic after governed allocation: `412670000`

## Decision

Approve one branch-only non-live build of the locked WTI monthly Mood raw-
return squared-rank scale-non-contraction continuation rule, followed by
strict Q01 and one paced Q02 enqueue if CPU admission permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source And R1

`APPROVED_WITH_EXPLICIT_SYNTHESIS_AND_METHOD_ACCESS_RISK`. The evidence
contains a complete governed read of the peer-reviewed WTI carrier paper, a
named peer-reviewed Mood squared-rank record with an explicit full-body
access boundary, and complete official signed-tag-pinned SciPy documentation
and source for the exact no-tie arithmetic.

The sources support the WTI monthly continuation carrier and pooled squared-
rank scale construction only. Fixed blocks, tie rejection, inclusive score-
center gate, six-month return side, CFD translation, activity boundary,
execution, risk, and lifecycle are pre-result QM synthesis.

## R2 Mechanical Contract

`APPROVED`. The card locks:

1. exact `XTIUSD.DWX` D1 carrier and one consumed attempt per broker month;
2. thirteen consecutive completed month-end closes and twelve adjacent log
   returns, excluding the current month;
3. fixed old/recent blocks of six, pooled raw-return sorting, anchored
   relative-tolerance tie rejection, ranks 1..12, and rank-sum 78;
4. exact `M_old=sum((R_old-6.5)^2)`, expectation 71.5, variance 364, and
   finite standardized statistic;
5. inclusive `M_old<=71.5` recent scale-non-contraction gate plus recent six-
   return cumulative sign;
6. one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` stop, spread cap,
   monthly exit, and forty-day stale repair; and
7. both news axes, legacy news mode, and Friday close OFF.

There is no optimization surface, fitted coefficient, probability lookup,
p-value, statistic-strength sizing, intramonth retry, external runtime input,
target, trail, grid, martingale, or scale-in.

## R3 Data

`APPROVED_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native
`XTIUSD.DWX` D1 history and MT5-native state provide every signal and
execution input. Q02 must expose roll/basis, financing, spread, gap, month-
label, and history-window failures.

## R4 Prohibited Logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, integer ranks, fixed arithmetic, comparisons, ATR risk,
quotes, orders, positions, deals, and terminal state. It has no trained
signal, prohibited signal indicator, random runtime sampling, or external
runtime feed.

## Pre-Result Activity Prior

Of 924 unique-rank six/six allocations, 426 are below the fixed score center,
72 equal it, and 426 are above. The inclusive rule therefore qualifies
498/924 allocations, an approximately 6.47-per-year state prior before
neutral side, data, and execution gates. It is not an empirical frequency or
alpha claim. Retire below five completed positions in any full post-warm-up
year.

## Dedup Adjudication

The corrected-root receipt scanned 4,766 identities, 1,403 cards, and 45 Wiki
nodes, finding no exact identity and two expected fuzzy matches. Ansari-
Bradley uses symmetric end weights and an exact label tail. Fligner-Killeen
centers blocks, ranks absolute deviations, and maps them to normal scores.
Mood uses one pooled raw-return integer-rank assignment, squared distance
from rank center, and a fixed expectation/variance. It neither centers raw
returns nor enumerates a permutation tail. Fixed fixtures prove both
decision-disagreement directions while the other closest neighbors stay
flat.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RAW_RETURN_POOLED_INTEGER_RANK_MOOD_SQUARED_RANK_RECENT_SCALE_NONCONTRACTION_CUMULATIVE_RETURN_CONTINUATION`.

## Build Order

1. Create `framework/EAs/QM5_41267_wti-mmood-scale-tr/` and copy the approved
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

