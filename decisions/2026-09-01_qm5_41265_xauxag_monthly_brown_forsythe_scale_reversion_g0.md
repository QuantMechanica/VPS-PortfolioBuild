# QM5_41265 XAU/XAG Monthly Brown-Forsythe Scale Reversion - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41265_xauxag-mbf-scale-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41265_xauxag-mbf-scale-rv_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901/source.md`
- Source approval commit: `7b13861f51`
- Identity reservation commit: `df1f868ce2`

## Decision

Approve one branch-only non-live build of the locked XAU/XAG monthly Brown-
Forsythe median-centered scale-expansion reversion basket, followed by strict
Q01 and one paced logical-basket Q02 enqueue if CPU admission permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source And R1

`APPROVED_WITH_EXPLICIT_SYNTHESIS_AND_METHOD_ACCESS_RISK`. The evidence
contains complete governed peer-reviewed gold/silver relationship evidence
and adverse findings, an official CME ratio-carrier record, a named peer-
reviewed Brown-Forsythe record with an explicit full-body access boundary, the
complete official NIST formula, and signed-tag-pinned SciPy implementation
evidence.

The sources support the carrier and median-centered scale arithmetic only.
Adjacent changes, fixed split, recent-expansion direction, median-shift fade,
CFD package, risk, and lifecycle are pre-result QM synthesis.

## R2 Mechanical Contract

`APPROVED`. The card locks:

1. exact XAUUSD.DWX host and XAGUSD.DWX companion on D1;
2. one consumed attempt within 180 minutes of a broker-month transition;
3. thirteen consecutive synchronized completed month-end pairs, excluding the
   current month;
4. twelve adjacent gold-minus-silver log-ratio changes in fixed old/recent
   blocks of six;
5. even medians from sorted indices two and three, followed by twelve median-
   centered absolute deviations;
6. exact group/grand means, between/within sums, multiplier ten, denominator
   floor `1e-18`, and finite Brown-Forsythe statistic;
7. relative `1e-12` recent-scale and median-shift comparisons plus exact
   contrarian pair sides;
8. aggregate `RISK_FIXED=1000`, equal target notionals, frozen per-leg
   `3.5*ATR(20,D1)` stops, spread caps, and 20 percent mismatch ceiling; and
9. atomic two-leg integrity, next-month exit, and forty-day stale repair.

There is no optimization surface, fitted coefficient, F critical-value or
p-value gate, statistic-strength sizing, intramonth retry, convergence target,
external runtime input, grid, martingale, or scale-in.

## R3 Data

`APPROVED_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
native XAU/XAG D1 histories and MT5-native state provide every signal and
execution input. Q02 must expose synchronization, basis, financing, spread,
gap, legging, and history-window failures.

## R4 Prohibited Logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, absolute values, fixed finite arithmetic, comparisons,
ATR risk, quotes, orders, positions, deals, and terminal state. It has no
trained signal, prohibited signal indicator, random runtime sampling, or
external runtime feed.

## Pre-Result Activity Prior

Equal-block label-swap symmetry places exactly one side of a non-tied scale
pair in the recent-expansion state, implying approximately six qualifying
states per twelve monthly attempts before market and execution gates. This is
not an empirical frequency or alpha claim. Retire below five completed
packages in every full post-warm-up year.

## Dedup Adjudication

The corrected-root receipt scanned 4,764 identities, 1,401 cards, and 45 Wiki
nodes, finding no exact identity. The one fuzzy match is the shared-carrier
Kuiper rule. Brown-Forsythe preserves within-block magnitudes and compares
group-specific median absolute deviations; Kuiper and Anderson-Darling pool
ranks and use full empirical-distribution paths plus exact label tails. Fixed
no-tie fixtures prove Brown-Forsythe-only, rank-only, and opposite-side
decisions. The daily ratio-level median/MAD and chronological CUSUM families
use different state objects, clocks, and exits.

## Build Order

1. Create `framework/EAs/QM5_41265_xauxag-mbf-scale-rv/` and copy the approved
   card into `docs/strategy_card.md`.
2. Allocate active magic rows for slots 0/1 only, regenerate the resolver, and
   verify no row is dropped.
3. Implement only the approved four-module behavior and exact reference
   fixtures.
4. Create the QM5_12533-style logical basket manifest plus one logical and two
   component `RISK_FIXED` backtest sets.
5. Compile through governed Q01, require zero errors/warnings and all static/
   reference checks, then enqueue exactly one logical Q02 row if CPU admission
   permits.

## Safety Boundary

Forbidden: manual tester launch, component-leg Q02 rows, optimization,
portfolio-gate mutation, correlation waiver, portfolio admission, live/demo/
shadow/stress presets, `T_Live`, AutoTrading, deploy/live manifest, or terminal
control. The basket manifest is pipeline metadata, not a live manifest.

