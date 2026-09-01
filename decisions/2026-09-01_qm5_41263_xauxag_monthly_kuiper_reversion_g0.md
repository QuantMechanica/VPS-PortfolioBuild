# QM5_41263 XAU/XAG Monthly Kuiper Reversion - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41263_xauxag-mkuiper-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MKUIPER-RV-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41263_xauxag-mkuiper-rv_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901/source.md`
- Source approval commit: `8c2ab49371`
- Identity reservation commit: `a02d841da1`

## Decision

Approve one branch-only non-live build of the locked XAU/XAG monthly exact-
permutation two-sample Kuiper distribution-shift reversion basket, followed by
strict Q01 and one paced logical-basket Q02 enqueue if CPU admission permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source And R1

`APPROVED_WITH_EXPLICIT_SYNTHESIS_RISK`. The evidence contains complete
governed peer-reviewed gold/silver relationship evidence and adverse findings,
an official CME ratio-carrier record, a complete read of Kuiper's primary
paper, and pinned official CRAN/source implementation evidence.

The sources support the carrier and statistical distance only. Adjacent
changes, fixed split, exhaustive exact tail, activity boundary, contrarian
side, CFD package, risk, and lifecycle are pre-result QM synthesis.

## R2 Mechanical Contract

`APPROVED`. The card locks:

1. exact XAUUSD.DWX host and XAGUSD.DWX companion on D1;
2. one consumed attempt within 180 minutes of a broker-month transition;
3. thirteen consecutive synchronized completed month-end pairs, excluding the
   current month;
4. twelve adjacent gold-minus-silver log-ratio changes in fixed old/recent
   blocks of six, with strict ties rejected;
5. two-sample Kuiper `V=D_plus+D_minus` over the pooled rank path;
6. all 924 fixed-size labels, inclusive tolerance, observed `V>=0.5`, and
   `tail_count<=798`;
7. recent pooled-rank sum around neutral 39 and exact contrarian pair sides;
8. aggregate `RISK_FIXED=1000`, equal target notionals, frozen per-leg
   `3.5*ATR(20,D1)` stops, spread caps, and 20 percent mismatch ceiling; and
9. atomic two-leg integrity, next-month exit, and forty-day stale repair.

There is no optimization surface, fitted coefficient, p-value, asymptotic
critical table, statistic-strength sizing, intramonth retry, convergence
target, external runtime input, grid, martingale, or scale-in.

## R3 Data

`APPROVED_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
native XAU/XAG D1 histories and MT5-native state provide every signal and
execution input. Q02 must expose synchronization, basis, financing, spread,
gap, legging, and history-window failures.

## R4 Prohibited Logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, fixed finite loops, arithmetic, comparisons, ATR risk,
quotes, orders, positions, deals, and terminal state. It has no trained signal,
prohibited signal indicator, random runtime sampling, or external runtime feed.

## Pre-Result Activity Prior

The exhaustive strict-label reference admits 798 of 924 assignments at
`V>=0.5`; 38 have neutral recent rank sum, leaving 760 directional states, or
`760/77 = 9.87012987` per twelve attempts. This is not an empirical frequency,
significance, or alpha claim. Retire below five completed packages in any full
post-warm-up year.

## Dedup Adjudication

The corrected-root receipt scanned 4,762 identities, 1,399 cards, and 45 Wiki
nodes, finding no exact identity. The one fuzzy match is a shared-carrier
Anderson-Darling rule. Fixed label path `RROROROOROOR` qualifies Kuiper but is
flat for both KS and Anderson-Darling; `RROROROROORO` is flat for Kuiper but
qualifies Anderson-Darling. Kuiper adds opposing ECDF extrema; it neither uses
one signed KS maximum nor an all-rank squared tail-weighted sum.

## Build Order

1. Create `framework/EAs/QM5_41263_xauxag-mkuiper-rv/` and copy the approved
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
