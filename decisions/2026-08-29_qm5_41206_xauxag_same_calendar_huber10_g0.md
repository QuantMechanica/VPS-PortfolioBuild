# QM5_41206 XAU/XAG Ten-Year Same-Calendar Huber Relative Seasonality - G0 Decision

Date: 2026-08-29

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41206_xauxag-samecal-huber10_card.md` and
only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41206`
- slug: `xauxag-samecal-huber10`
- strategy ID: `KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026_S01`
- source ID: `KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- logical basket: `QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1`
- intended magics: `412060000`, `412060001`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41206` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026/source.md`,
SHA-256
`1979F66E61B1CA514BD2E89EF75912C4550ABEECEC0C5A98D9D7C476997A22A9`.
Its durable source approval is
`decisions/2026-08-29_xauxag_same_calendar_huber10_source_approval.md`,
committed before extraction as `342e07a71`.

R1 is `PASS_WITH_COMPOSITE_ESTIMATOR_PAIR_AND_CFD_TRANSLATION_RISK`.
Complete-read DOI-bearing peer-reviewed trading lineages support the
same-calendar information and governed XAU/XAG carrier; peer-reviewed Huber
lineage plus a complete governed packet supports the bounded-location
arithmetic. The exact conjunction is untested. No performance, density, cost,
hedge, CFD-equivalence, or decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. At each genuine normalized broker-month D1 transition, the
card:

1. repairs owned exposure and consumes the month before fallible gates;
2. reconstructs synchronized completed XAU and XAG same-calendar returns in
   every exact year `Y-1..Y-10` under one uniform label convention;
3. forms `d=r_xau-r_xag`, the exact even median and raw MAD, freezes
   `delta=1.5*1.4826*MAD`, and runs exactly 32 finite Huber updates;
4. follows the strict final-location sign as an opposite-direction package;
   and
5. renews at the next month boundary, with 40 days as survivor repair only.

One `RISK_FIXED=1000` package budget is split into equal fixed-risk halves;
each leg receives a frozen `3.5*ATR(20,D1)` hard stop. Both news axes, legacy
news mode, and Friday close are OFF. There is no parameter sweep or
result-dependent rescue.

## Data And Determinism

R3 is `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`.
Registered XAU/XAG D1 histories, broker time, quotes, contract metadata,
positions, deals, and terminal-persistent attempt state provide every runtime
field. Q02 must prove usable labels, exact-year synchronized history, density,
fills, package economics, and costs.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, sorting,
absolute deviations, fixed weights, and comparisons; ATR is bounded risk
plumbing. No trained output, banned signal indicator, external runtime feed,
grid, martingale, scale-in, pyramid, or adaptive PnL fit exists.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xauxag_samecal_huber10_preallocation_dedup_20260829.json`,
SHA-256
`5EF82AF457CF175BE027E302B1824621876059C6BFB11FC0EC4FA2646D078EC6`,
found no exact identity across 4,705 registry rows, 1,351 cards, and all 45
current Strategy Wiki nodes.

Manual review resolves all fuzzy neighbors:

- `QM5_20186` uses a raw arithmetic mean with no robust scale or iteration.
- `QM5_41203` uses signed absolute ranks and discards metric distances.
- `QM5_41204` and `QM5_41205` own standalone energy positions; this card owns
  a synchronized atomic cross-metal package.
- Existing ratio, residual, recent-window, channel, and session baskets use
  different state functionals.

The locked ten-return vector makes the Huber location negative while both the
raw mean and signed-rank score are positive. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_EXACT_TEN_YEAR_SAMECAL_FIXED_SCALE_HUBER_RELATIVE_LOCATION_MONTHLY_BASKET`.

## Portfolio Intent And Falsification

This is an opposite-leg precious-metals relative-value stream, not another
outright XAU strategy. Its disjoint historical matching-month sample, robust
location statistic, shared-risk package, and monthly lifecycle differ from
the certified directional XAU stream. That does not prove low factor or
portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero packages, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any label, endpoint,
synchronization, exact-year, relative-orientation, median, MAD, scale, weight,
iteration, side, attempt, atomicity, risk, stop, lifecycle, or determinism
defect. No sample, estimator, tuning, update count, side, stop, hold, spread,
or gate may change after results to rescue the lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slots 0 and 1;
- one branch-only V5 EA build;
- one exact D1 `RISK_FIXED` logical-basket backtest setfile and manifest;
- strict compile and Q01 validation; and
- one paced logical-basket Q02 enqueue if active factory CPU remains below
  the hard ceiling.

It does not permit a manual backtest, component-leg Q02 rows, terminal
control, live/demo/shadow/stress/optimization setfiles, `T_Live`, AutoTrading,
deploy or live manifests, portfolio-gate mutation, portfolio admission, or a
correlation waiver.

## Card Binding

The approved card SHA-256 at decision time is
`749C90321924C82C1FAE91582912DE1C686EBF2C2371C19547009C982F5627BA`.
Any mechanical change requires a new decision or formally governed successor;
editorial evidence additions must not alter the execution contract.
