# QM5_41115 WTI Completed-Month Three-Block Vote Momentum - G0

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the committed source approval
`e3b7b5d15` and the non-live safety restrictions recorded there.

## Identity

- EA ID: `QM5_41115`
- slug: `wti-mthirdvote-mom`
- strategy ID: `MOP-WTI-MTHIRDVOTE-MOM-2026_S01`
- source ID: `MOP-WTI-MTHIRDVOTE-MOM-2026`
- host and logical symbol: exact `XTIUSD.DWX`
- timeframe: exact D1
- symbol slot: 0
- planned magic: `411150000`

The deterministic EA-ID reservation is commit `9f2517a77`. The approved card
is `strategy-seeds/cards/approved/QM5_41115_wti-mthirdvote-mom_card.md`.

## Source Gate

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MTHIRDVOTE-MOM-2026/source.md`, committed at
`ff371aada`. Its parent record,
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, was read completely and has
SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent records the complete published paper by Tobias J. Moskowitz, Yao
Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, with published-PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper supplies monthly own-price continuation, a one-month formation and
one-month holding rule within pooled commodities, and explicit WTI carrier
lineage. It does not supply a WTI-only three-block vote, continuous-CFD
equivalence, fixed-risk execution, performance, density, or decorrelation.
Those are disclosed QM hypotheses.

## Approved Mechanic

At the first tradable normalized D1 bar of a new broker month, and within 180
elapsed minutes of its raw open, reconstruct the immediately completed month
and its consecutive parent. Each must contain 17 through 23 unique sessions
under one uniform raw or `+1`-day energy-label convention.

Let `P` be the parent month's final chronological close and let
`C[0]...C[n-1]` be all chronological closes in the newest completed month.
Set:

```text
a       = floor(n / 3)
b       = floor(2 * n / 3)
block_1 = log(C[a-1] / P)
block_2 = log(C[b-1] / C[a-1])
block_3 = log(C[n-1] / C[b-1])
```

Buy only when at least two block returns are strictly positive. Sell only
when at least two are strictly negative. Zero casts no vote. Invalid
arithmetic, invalid partition, malformed history, current-month leakage, or
no strict majority consumes the month flat. Block magnitudes do not weight
direction or sizing, and full-month endpoint agreement is deliberately not
required.

Persist the decision `yyyymm` before history, signal, spread, quote, ATR,
sizing, or order gates. Use one fixed-dollar position with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5 * ATR(20,D1)` hard stop,
no target, and a 1,500-point spread ceiling. Both news axes and Friday close
are OFF. Flatten on the first later normalized broker month, with forty
calendar days as stale repair only.

## Non-Duplicate Finding

Before allocation, the canonical checker used the exact slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,611 EA-registry identities, 1,283 repository cards, and 45
Strategy-Wiki nodes and returned `CLEAN` with no exact or fuzzy match.
Evidence:
`artifacts/qm5_wti_mthirdvote_mom_preallocation_dedup_20260822.json`.

After allocation, the same checker scanned 4,612 registry identities, 1,283
cards, and 45 Wiki nodes. The only exact hits were the newly reserved
`QM5_41115` slug and strategy ID. They are expected self-hits, not evidence of
a second implementation. Evidence:
`artifacts/qm5_41115_wti_mthirdvote_mom_postallocation_dedup_20260822.json`.

Manual semantic review found no foreign duplicate:

- `QM5_41114` requires agreement across two halves; QM5_41115 permits one
  opposing block through a strict two-of-three vote.
- `QM5_41111` counts every daily return and requires endpoint agreement;
  QM5_41115 casts three cumulative block votes and has no endpoint filter.
- `QM5_20272` votes four three-month blocks across a year; QM5_41115 votes
  three blocks inside one month.
- `QM5_20187` follows the full-month endpoint sign; QM5_41115 can take the
  opposite direction when the internal block majority differs.
- `QM5_41021` uses a nested final-five confirmation and five-session hold;
  QM5_41115 uses exhaustive non-overlapping blocks and a one-month hold.
- certified `QM5_12567` is a long-only two-day XNG RSI2 pullback.

Verdict:
`CLEAN_WTI_COMPLETED_MONTH_THREE_EXHAUSTIVE_BLOCK_STRICT_MAJORITY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## R1-R4 Findings

- R1 `PASS_WITH_THREE_BLOCK_TRANSLATION_RISK`: peer-reviewed named source,
  DOI, complete-read evidence, durable hashes, and explicit WTI membership;
  the three-block vote is disclosed as untested.
- R2 `PASS`: clock, label normalization, consecutive months, session bounds,
  parent anchor, floor-third boundaries, exhaustive blocks, zero handling,
  strict vote, attempt, risk, spread, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 and MT5 state supply all runtime data. Q02 owns label,
  cadence, cost, and continuous-CFD sufficiency.
- R4 `PASS`: timestamp and close arithmetic plus framework state only; no ML,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

The required card schema and prohibited-method lint passes with no missing
sections and no ML hits.

## Build Authorization

Development may build exactly the approved card after creating the EA
directory and allocating one active slot-zero magic row in governed order.
The build must preserve:

- exact `XTIUSD.DWX`, D1, slot zero, and registered magic;
- the uniform label and two-consecutive-completed-month contract;
- all 17-to-23-session floor-third partitions;
- exhaustive non-overlapping blocks and strict two-of-three sign voting;
- magnitude-blind direction with no endpoint-agreement filter;
- the persisted one-attempt rule;
- one fixed-risk ATR-stopped position and next-month exit; and
- the no-live, no-portfolio-mutation boundary.

Q01 requires a deterministic reference suite, card/source alignment,
resolver identity, one canonical fixed-risk backtest set, strict compile,
zero errors and warnings, non-empty EX5, and build-check PASS. Q02 may receive
exactly one paced work item only after Q01 passes and a fresh CPU/capacity
check permits it. A blocked compile or CPU ceiling must be recorded and left
for governed continuation; it does not authorize an ad-hoc tester or terminal
action.

## Falsification

Q02 retires on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, invalid labels or month
membership, wrong partition endpoints, skipped or duplicated returns, wrong
zero handling or vote, current-month leakage, duplicate attempts, invalid
risk, missing stop, lifecycle drift, or nondeterminism. No post-result rescue
through boundary, vote, endpoint-filter, hold, session-bound, or added-filter
changes is authorized.

## Safety Boundary

This approval permits research, allocation, a branch-only non-live build,
strict Q01, and one paced Q02 enqueue if capacity permits. It authorizes no
manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest mutation, portfolio-gate change,
portfolio admission, decorrelation claim, correlation waiver, or live use.
