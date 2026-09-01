# QM5_41260 XAU/XAG Monthly Anderson-Darling Reversion - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41260_xauxag-mad2-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MAD2-RV-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41260_xauxag-mad2-rv_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/source.md`
- Source approval commit: `7bc1b90109`
- Identity reservation commit: `ffb01e510a`

## Decision

Approve one branch-only non-live build of the locked XAU/XAG monthly exact-
permutation Anderson-Darling distribution-shift reversion basket, followed by
strict Q01 and one paced logical-basket Q02 enqueue if the CPU admission gate
permits.

G0 approves mechanization and the execution contract. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Source And R1

`APPROVED` with explicit synthesis risk. The evidence set contains:

- complete peer-reviewed gold/silver relationship evidence and adverse
  findings;
- an official CME intermarket-carrier record;
- the complete Scholz-Stephens peer-reviewed Anderson-Darling article; and
- pinned SciPy 1.13.1 official documentation and source.

The sources support only the carrier and method objects. The adjacent-change
state, fixed split, half-tail, contrarian side, CFD package, risk, and
lifecycle are pre-result QM synthesis.

## R2 Mechanical Contract

`APPROVED`. The card locks:

1. exact XAUUSD.DWX host and XAGUSD.DWX companion on D1;
2. one attempt within 180 minutes of a genuine broker-month transition;
3. thirteen consecutive synchronized completed month-end pairs with no
   current-month price;
4. twelve adjacent gold-minus-silver log-ratio changes in fixed six/six
   old/recent blocks;
5. strict change ties, all eleven pooled-rank cuts, the continuous two-sample
   Anderson-Darling formula, and finite arithmetic;
6. all 924 fixed-size label assignments, inclusive relative tolerance,
   `tail_count<=452`, and the exact half-tail identity;
7. recent pooled-rank sum around neutral 39 and exact contrarian pair sides;
8. month consumption before fallible gates;
9. one aggregate `RISK_FIXED=1000` budget, equal target notionals, frozen
   `3.5*ATR(20,D1)` stops, spread caps, and 20 percent mismatch ceiling;
10. atomic two-leg integrity, next-month exit, and forty-day stale repair.

There is no optimization surface, fitted coefficient, p-value, asymptotic
critical table, statistic-strength sizing, intramonth retry, convergence
target, external runtime input, grid, martingale, or scale-in.

## R3 Data

`APPROVED_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
native XAU/XAG D1 histories and MT5-native state provide all signal and
execution inputs. Q02 must expose missing synchronization, CFD basis,
financing, spread, gap, legging, and history-window failures.

## R4 Prohibited Logic

`APPROVED`. The rule uses deterministic timestamps, completed prices,
logarithms, sorting, fixed finite loops, arithmetic, comparisons, ATR risk,
quotes, orders, positions, deals, and terminal state. It contains no trained
signal, prohibited signal indicator, or external runtime feed.

## Pre-Result Activity Prior

The exhaustive strict-rank reference admits 452 of 924 assignments at the
half-tail. Four have neutral recent rank sum, leaving 448 directional states,
about 5.818 per twelve attempts. This is not an empirical frequency or alpha
claim. Retire below five completed packages in any full post-warm-up year.

## Dedup Adjudication

The corrected-root canonical check scanned 4,759 identity rows, 1,396 cards,
and 45 Strategy Wiki nodes and found no exact identity. The fuzzy carrier
neighbors are not aliases:

- KS uses ratio levels and one maximum signed ECDF gap;
- Mann-Whitney uses one rank sum on ratio levels;
- monthly CUSUM mean-centers changes and searches one chronological maximum;
- daily MAD uses a rolling median/scale cross; and
- this card uses adjacent monthly ratio changes, every tail-weighted pooled-
  rank cut, and an exact 924-assignment inclusive tail.

Fixed paths prove both disagreement directions versus KS: `RROROROROORO`
qualifies Anderson-Darling at tail 428 but KS is flat; `RORRROOORORO`
qualifies KS but is flat here at tail 484.

## Build Order

1. Create `framework/EAs/QM5_41260_xauxag-mad2-rv/` and copy the approved
   card into `docs/strategy_card.md`.
2. Allocate active magic rows for slots 0/1 only, regenerate the resolver, and
   verify no row is dropped.
3. Implement only the approved four-module behavior and reference fixtures.
4. Create the QM5_12533-style logical basket manifest plus one canonical
   logical `RISK_FIXED` backtest set and component validation sets.
5. Compile through the governed Q01 path, require zero errors/warnings and all
   static/reference checks, then enqueue exactly one logical Q02 row if CPU
   admission permits.

## Safety Boundary

Forbidden: manual tester launch, component-leg Q02 rows, optimization,
portfolio-gate mutation, correlation waiver, portfolio admission, live/demo/
shadow/stress presets, T_Live, AutoTrading, deploy/live manifest, or terminal
control. The basket manifest is pipeline metadata, not a live manifest.
