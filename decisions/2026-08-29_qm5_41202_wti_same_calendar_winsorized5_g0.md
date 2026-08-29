# QM5_41202 WTI Five-Year Same-Calendar Winsorized - G0 Decision

Date: 2026-08-29

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41202_wti-samecal-win5_card.md` and only the
non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41202`
- slug: `wti-samecal-win5`
- strategy ID: `KELOHARJU-WINSOR-WTI-SAMECAL5-2026_S01`
- source ID: `KELOHARJU-WINSOR-WTI-SAMECAL5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412020000`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41202` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-WINSOR-WTI-SAMECAL5-2026/source.md`, SHA-256
`90DCEE1100A637DB2AFBDBE7D162CA2A284D687E6F3D87352E92633FF19056A9`.
Its durable source approval is
`decisions/2026-08-29_wti_same_calendar_winsorized5_source_approval.md`,
committed before extraction as `aecbc325e`.

R1 is `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`. Complete-read
peer-reviewed lineages directly support same-calendar commodity returns,
explicit crude-oil and WTI membership, and the governed fixed-tail arithmetic.
The exact conjunction is untested. No performance, density, cost,
CFD-equivalence, or decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. At each genuine normalized broker-month D1 transition, the card:

1. repairs owned exposure and consumes the month before fallible gates;
2. reconstructs exactly one completed same-calendar return from every exact
   year `Y-1..Y-5` under one uniform energy-label convention;
3. sorts all five returns, caps the minimum at the second order statistic and
   the maximum at the fourth, and averages the exact five retained terms;
4. follows the strict Winsorized-mean sign with no magnitude sizing; and
5. renews at the next month boundary, with 35 days as survivor repair only.

One `RISK_FIXED=1000` budget and a frozen `3.5*ATR(20,D1)` hard stop are used.
Both news axes, legacy news mode, and Friday close are OFF. There is no
parameter sweep or result-dependent rescue.

## Data And Determinism

R3 is `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
Registered `XTIUSD.DWX` D1 history, broker time, quotes, contract metadata,
positions, deals, and terminal-persistent attempt state provide every runtime
field. Q02 must prove usable labels, complete exact-year history, density,
fills, and economics.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, sorting,
fixed replacement, and comparisons; ATR is bounded risk plumbing. No trained
output, banned signal indicator, external runtime feed, grid, martingale,
scale-in, pyramid, or adaptive PnL fit exists.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_win5_preallocation_dedup_20260829.json`, SHA-256
`6D713EC4B7A3D231EE05D483C4D706E7B69727ECB3F6F7034945B2052BBF3448`, found
no exact identity across 4,701 registry rows, 1,347 cards, and all 45 current
Strategy Wiki nodes.

Manual review separates the raw mean, raw median, positive-hit, ten-year
signed-rank, middle-three trim, five-return inclusive-pair pseudomedian, and
twelve-contiguous-return Winsorized neighbors. The vectors
`[-12,-11,3,9,10]` and `[-12,-9,3,8,9]` prove side disagreement against the
closest estimators.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_ONE_TAIL_WINSORIZED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Portfolio Intent And Falsification

Direct WTI adds crude-oil exposure absent from the certified directional
XAU/SP500/NDX/XNG book. This economic distinction does not prove low factor or
portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, endpoint,
exact-year, sort, replacement, retained-weight, divisor, side, attempt, risk,
stop, lifecycle, or determinism defect. No carrier, estimator, tail count,
side, stop, hold, spread, or gate may change after results to rescue the
lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slot 0;
- one branch-only V5 EA build;
- one exact D1 `RISK_FIXED` backtest setfile;
- strict compile and Q01 validation; and
- one paced Q02 enqueue if the active factory remains below its CPU ceiling.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate mutation, portfolio admission, or a correlation waiver.
