# QM5_41200 WTI First-Half-of-Month Short - G0 Decision

Date: 2026-08-29

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41200_wti-h1m-short_card.md` and only the
non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41200`
- slug: `wti-h1m-short`
- strategy ID: `BOROWSKI-WTI-H1M-2026_S01`
- source ID: `BOROWSKI-WTI-H1M-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412000000`

The atomic allocator reserved row `41200` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded source packet is
`strategy-seeds/sources/BOROWSKI-WTI-H1M-2026/source.md`, SHA-256
`56958E78F5514C2C8E4A42AF8D8995E0234C32512465F597BC40EFE8A99CDCF9`.
Its durable approval is
`decisions/2026-08-29_wti_first_half_month_short_source_approval.md`, committed
before extraction as `bcea29578`; amendment `878a92250` turns Friday close OFF
so the build preserves the complete approved first-half interval.

R1 is `PASS_WITH_NONSIGNIFICANCE_AND_CFD_TRANSLATION_RISK`. Complete-read,
named-author, peer-reviewed Tier-B evidence directly reports a negative WTI
average return over calendar days 1-15. The between-half result is
non-significant and the sample predates this CFD carrier. No performance,
significance, density, cost, CFD-equivalence, or decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. On the first executable tick after each genuine normalized
broker-month D1 transition, the card:

1. repairs owned exposure and consumes the month before fallible gates;
2. accepts only a native or uniform `+1` D1-label convention that maps the
   current bar to the broker date;
3. requires the opening segment (day at most 5 and attachment age at most 180
   minutes);
4. sells one fixed-risk WTI position with a frozen `2.75*ATR(20,D1)` hard stop
   and no target; and
5. exits at the first later normalized D1 bar dated 16 or greater, with 20
   elapsed days as survivor repair only.

One `RISK_FIXED=1000` budget is used. Both news axes, the legacy news mode, and
Friday close are OFF. There is no parameter sweep or result-dependent rescue.

## Data And Determinism

R3 is `PASS_WITH_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
Registered `XTIUSD.DWX` D1 history, broker time, quotes, contract metadata,
positions, deals, and terminal-persistent attempt state provide every runtime
field. Q02 must prove usable labels, density, fills, and economics.

R4 is `PASS`. The entry uses only calendar comparisons and native execution
state; ATR is bounded risk plumbing, not a direction signal. No trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in,
pyramid, or adaptive PnL fit exists.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_h1m_short_preallocation_dedup_20260829.json`, SHA-256
`0B3DCBD710F229E0F2342D93E4F8205F2809D73F8C9A3451BB8529CE954314B4`,
found no exact identity across 4,699 registry rows, 1,345 cards, and all 45
Strategy Wiki nodes. Manual review establishes that `QM5_20021` owns the
complementary second half, `QM5_20028` is an opposite-side one-session date-1
trade, `QM5_20027` is a one-session date-26 trade, and the remaining surfaced
cards use XNG or weekday clocks.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_FIRST_GENUINE_MONTH_BOUNDARY_SHORT_TO_FIRST_DAY_GE_16`.

## Portfolio Intent And Falsification

Direct WTI adds crude-oil exposure absent from the certified directional
XAU/SP500/NDX/XNG book. This economic distinction does not prove low factor or
portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, boundary,
attachment, side, attempt, risk, stop, exit, or determinism defect. No carrier,
date, side, stop, hold, spread, or gate may change after results to rescue the
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
