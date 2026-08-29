# QM5_41207 XAU/XAG Weekly Correlation-Break Relative-Value Fade - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41207_xauxag-corrbreak-rv_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41207`
- slug: `xauxag-corrbreak-rv`
- strategy ID: `KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01`
- source ID: `KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- logical basket: `QM5_41207_XAU_XAG_CORRBREAK_RV_D1`
- intended magics: `412070000`, `412070001`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41207` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026/source.md`,
SHA-256
`7AF659643DF0CCD6AF645815882545F7336CA96705DC678A76880A91613416D3`.
Its durable source approval is
`decisions/2026-08-30_xauxag_correlation_break_reversion_source_approval.md`,
committed before extraction as `e75f465f1`.

R1 is `PASS_WITH_COMPOSITE_STATE_TRANSLATION_AND_CFD_RISK`.
Complete-read peer-reviewed lineages support positive daily gold/silver
dependence, gold-to-silver ordering in one historical sample, and a
state-dependent rather than constant relationship. Governed CME material
supports the relative-value carrier. The exact correlation-break fade is an
untested QM hypothesis, and the sources' adverse findings remain binding. No
performance, density, cost, hedge, CFD-equivalence, or decorrelation result
transfers.

## Mechanical Decision

R2 is `PASS`. At each genuine first broker-week host D1 bar, the card:

1. repairs owned exposure and consumes the week before fallible entry gates;
2. loads exactly 81 synchronized completed XAU/XAG D1 close pairs and forms
   80 adjacent returns with no current-bar input;
3. computes Pearson correlation over the oldest 60 and newest disjoint 20
   returns, plus the locked Fisher z-drop;
4. requires baseline/recent/raw-drop/z-drop boundaries of
   `0.50/0.35/0.25/1.645`;
5. computes the newest five-session XAU-minus-XAG displacement against the
   old-60 relative-return mean and sample scale and requires
   `abs(score)>=1.25`;
6. fades the relative winner with one equal-notional opposite-leg package;
7. freezes the exact halfway log-ratio retracement target; and
8. exits on target, 15 completed D1 bars, or 24 elapsed days.

One `RISK_FIXED=1000` package budget is split into equal fixed-risk halves;
each leg receives a frozen `3.5*ATR(20,D1)` hard stop. Both news axes, legacy
news mode, and Friday close are OFF. There is no parameter sweep, overlapping
window, fitted hedge, fallback signal, current-bar path, or result-dependent
rescue.

## Data And Determinism

R3 is `PASS_WITH_SYNCHRONIZATION_CONTINUOUS_CFD_AND_LEGGING_RISK`.
Registered XAU/XAG D1 histories, broker time, quotes, contract metadata,
positions, deals, and terminal-global attempt/package state provide every
runtime field. Q02 must prove usable timestamp alignment, density, fills,
package accounting, costs, and continuous-CFD behavior.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, ordinary
sums/products, square roots, a fixed Fisher transform, and comparisons; ATR is
bounded risk plumbing. No trained output, banned signal indicator, external
runtime feed, grid, martingale, scale-in, pyramid, or adaptive PnL fit exists.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xauxag_corrbreak_rv_preallocation_dedup_20260830.json`, SHA-256
`970112BA5AF89F0645D21AED1F28BACB50746D9C180FB4C802F0C8BD9295B1BF`,
found no exact identity across 4,706 registry rows and 1,352 cards. The
configured Strategy Wiki root was absent, so no Wiki coverage is claimed.

Manual review resolves the only fuzzy family:

- `QM5_41031_xauxag-goldlead` uses one gold shock and silver under-response,
  has no disjoint dependence transition, and exits next day;
- ratio, OLS/CADF, MAD, tail, and quantile systems estimate relative levels or
  fitted centers, while this card estimates none;
- the return-spread z-score family has no load-bearing high-to-low
  Pearson/Fisher break; and
- variance-ratio, weekly flow/path/common-shock, and same-calendar systems
  observe different states.

Verdict:
`FUZZY_GOLDLEAD_RESOLVED_DISTINCT_DISJOINT_CORRELATION_BREAK_PLUS_FIVE_SESSION_RELATIVE_DISPLACEMENT_FADE`.

## Portfolio Intent And Falsification

This is an opposite-leg precious-metals dependence-break stream, not another
outright XAU strategy. Its disjoint correlation state, standardized recent
relative displacement, fixed halfway target, equal notionals, and atomic
package differ from the certified XAU carrier. That does not prove low factor
or portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero packages, fewer than five packages in any full
post-warm-up year, nonpositive governed economics, or any clock, endpoint,
synchronization, ordering, block, Pearson/Fisher, scale, score, side, attempt,
target, atomicity, risk, stop, lifecycle, or determinism defect. No window,
threshold, statistic, side, target, stop, hold, spread, or gate may change
after results to rescue the lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slots 0 and 1;
- one branch-only V5 EA build;
- one exact D1 `RISK_FIXED` logical-basket backtest setfile and manifest;
- strict compile and Q01 validation; and
- one paced logical-basket Q02 enqueue if active factory CPU remains below the
  hard ceiling.

It does not permit a manual backtest, component-leg Q02 rows, terminal
control, live/demo/shadow/stress/optimization setfiles, `T_Live`, AutoTrading,
deploy or live manifests, portfolio-gate mutation, portfolio admission, or a
correlation waiver.

## Card Binding

The approved card SHA-256 at decision time is
`D32571DD2C63F9B22DB4D7CF6C92E4D69F042A9B0E76B874FA6E72AA081FCD9E`.
Any mechanical change requires a new decision or formally governed successor;
editorial evidence additions must not alter the execution contract.

## Pre-Q02 Q01 Execution-Contract Amendment

The first governed compile item
`673f05ea-b106-4de1-8607-3df23d51e2d6` compiled source SHA-256
`5FB24A43D232FB4BFBA613D02735AD4B8AD7A01A89824847FEF013D3FB3C0F1E`
with zero compiler errors and warnings, but its build check emitted
`BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED`: `.DWX` tester history may
legitimately model `Ask==Bid`, so the original strictly-positive-spread gate
would make every entry unreachable. Receipt SHA-256:
`90F8A719F54D41EFE13C2ABD705D44EBC4D36E37C63BBB51C7F1A9A4E90CFF2A`.

Before any Q02 row or result existed, the same OWNER mission therefore
authorizes exactly one execution-plumbing correction:

- positive finite Bid and Ask remain mandatory;
- crossed quotes (`Ask<Bid`) remain rejected;
- exact zero modeled spread (`Ask==Bid`) is permitted for this non-live `.DWX`
  Q02 identity; and
- the XAU/XAG 1,500/3,000-point ceilings remain unchanged.

No signal, window, threshold, side, target, risk, stop, hold, notional,
frequency, or portfolio rule changes. This is a zero-trade reachability repair
from Q01 static evidence, not a result-dependent rescue. It authorizes the
source successor SHA-256
`FFBFC3E4845CCBC87C73ADB6E6DDF6F8A1CD8E4ECEC78B6382C96FD920B8812A`
and updated card SHA-256
`CAF01CAB7568DFAAD486E18E8BFDF1B987A2ABDDDDF7FA1FBDF6A38FA6300318`.
A fresh governed source-repair compile with zero errors, zero warnings, and
build-check PASS is required before the build may be recorded or Q02 enqueued.
