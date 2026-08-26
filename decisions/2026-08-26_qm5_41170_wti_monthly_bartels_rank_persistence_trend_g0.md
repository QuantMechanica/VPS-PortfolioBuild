# QM5_41170 WTI Monthly Bartels Rank-Persistence Trend — G0 Decision

Date: 2026-08-26

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-26_wti_monthly_bartels_rank_persistence_trend_source_approval.md`.

Scope: approve one card, one registered V5 identity, one non-live build, strict
Q01 validation, independent review, and at most one paced Q02 enqueue. This is
not a performance, certification, correlation, portfolio-admission, deploy,
or live decision.

## Approved Identity

- EA ID: `QM5_41170`
- slug: `wti-bartels-rank-tr`
- strategy ID: `MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026_S01`
- source ID: `MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41170_wti-bartels-rank-tr_card.md`
- host and traded symbol: `XTIUSD.DWX`, slot 0
- timeframe: D1
- risk for every backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The deterministic allocator reserved row 41170 only after the source gate and
canonical dedup scan passed. Registry slug and strategy ID match the card.

## Source And Extraction Gate

Source approval commit: `20156b9a5b0e9151f67fb2935426e97383299041`.

Bounded records:

- complete governed Moskowitz-Ooi-Pedersen WTI source packet;
- Bartels (1982), JASA 77(377), DOI
  `10.1080/01621459.1982.10477764`, with the original body explicitly not
  claimed as completely read;
- complete `randtests` 1.0.2 files at public mirror commit
  `7244d86764445e657634c9ae4d59ce942a5fcbc8`, including exact formula and
  method documentation.

Evidence hashes:

- source packet:
  `1F9C14B8EF36D2A118AC7DEFB14BDEFBEA25C537301207EFECF521138EF16348`;
- source approval:
  `8D4CD6E0419B0B4848FAF421086CE63E90508B43F06B1531161A37CDF5D6E471`;
- canonical dedup receipt:
  `03C4061B2DA5BE53933F95FA78DF730BC96FA8D3EE436B5C39D39D0A3152D198`.

`framework/scripts/skill_card_schema_lint.py` returned `status: ok`, no
forbidden-token hits, and no missing required sections before approval.

## Locked Strategy Contract

At the first executable D1 tick of each genuine new broker month:

1. Persist the normalized broker `yyyymm` before every fallible gate.
2. Select the latest D1 close in each of the immediately preceding thirteen
   consecutive completed broker months. Exclude the current month. Require
   positive, finite, pairwise-distinct closes, strict chronology, and newest
   endpoint staleness no greater than ten calendar days.
3. Assign ordinal ranks 1..13, smallest to largest, and require the exact rank
   permutation plus denominator invariant
   `sum((R[i]-7)^2)=182`.
4. Calculate integer
   `NM=sum((R[i+1]-R[i])^2, i=0..11)`.
5. Qualify only when `NM<364`, the exact integer form of `RVN<2`. If
   qualified, buy when newest close exceeds oldest and sell when newest is
   below oldest. Otherwise consume the month flat.
6. Attach one frozen `3.5*ATR(20,D1)` hard stop, no target, and reject spread
   above 1,500 points. Own at most one slot-zero WTI position.
7. Exit on the first later broker month or after forty calendar days. Repair
   malformed, duplicate, wrong-side, wrong-symbol, wrong-magic, invalid-volume,
   or stopless owned exposure immediately.

News temporal mode is OFF, news compliance is NONE, legacy news is OFF, and
Friday close is OFF. P-values, tie averaging, parameter fitting, alternate
boundaries, fallback signals, filters, scale-in, grid, martingale, and
external runtime data are forbidden.

## Gate Findings

| Gate | Verdict | Basis |
|---|---|---|
| R1 | PASS | Complete-read peer-reviewed WTI carrier evidence, peer-reviewed Bartels method record, and complete pinned CRAN implementation; exact trading conjunction disclosed as untested. |
| R2 | PASS | Clock, month reconstruction, strict ranks, invariant, numerator, boundary, direction, attempt, risk, stop, and lifecycle are fully mechanical. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 archive and native MT5 state provide every runtime input; continuous-CFD basis remains a downstream risk. |
| R4 | PASS | Deterministic ranks, integer arithmetic, timestamps, ATR risk controls, and state only; no trained signal or banned runtime dependency. |

The card linter and R1-R4 consistency checks remain build preconditions. G0
does not transfer any expected performance or significance claim.

## Non-Duplicate Gate

The canonical fail-closed checker returned `CLEAN` across 4,669 registry rows,
1,320 cards, and 45 Strategy Wiki nodes.

Manual review establishes exact functional separation:

- Mann-Kendall uses all ordered pair signs; this candidate uses squared
  adjacent rank distances.
- path efficiency uses price magnitudes; this candidate becomes ordinal before
  computing its path statistic.
- Cox-Stuart uses seven disjoint half-sample pairs among fourteen endpoints;
  this candidate uses twelve adjacent distances among thirteen endpoints.
- Foster-Stuart counts new records; this candidate counts none.
- the incumbent certified XNG sleeve is a two-day long-only oscillator
  pullback on a different carrier and clock.

The two locked rank fixtures in the source approval produce opposite
admission decisions versus Mann-Kendall and Foster-Stuart. Changing the
formation, rank rule, denominator, strict boundary, endpoint direction, or
clock destroys this decision identity.

Verdict: `CLEAN_WTI_MONTHLY_BARTELS_RANK_RVN_LT2_ENDPOINT_TREND`.

## G0 Authorization And Kill Boundary

The card is approved for build because the source is durable, the rule is
mechanical, the identity is clean, the data route exists, and the proposed EA
uses only permitted structural arithmetic. It is not approved because an edge
or decorrelation has been observed.

Expected pre-result activity is 5-8 completed positions/year, centered near
6/year. Retire at zero trades, below five completed positions in any full
post-warm-up year, nonpositive governed economics, any state/rank/side/risk
defect, nondeterminism, or any downstream gate failure. A failed result cannot
be rescued by changing the sample, boundary, direction, risk, stop, hold,
carrier, or by adding a filter.

The current factory resource ceiling is binding. Source/card/build work may
remain CPU-light, but this G0 decision does not authorize compile, tester
dispatch, reservation, reaping, reprioritization, or terminal control while
the ceiling persists. Q02 may be enqueued exactly once only after a current
strict compile/Q01 PASS and independent review PASS.

Excluded: manual backtests, live/demo/shadow/stress/optimization setfiles,
`T_Live`, AutoTrading, deploy or live manifests, portfolio-gate edits,
portfolio admission, correlation waiver, and any claim of certification.

