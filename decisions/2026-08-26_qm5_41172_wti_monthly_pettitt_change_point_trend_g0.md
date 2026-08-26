# QM5_41172 WTI Monthly Pettitt Central Change-Point Trend — G0 Decision

Date: 2026-08-26

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-26_wti_monthly_pettitt_change_point_trend_source_approval.md`.

Scope: approve one card, one registered V5 identity, one non-live build,
strict Q01 validation, independent review, and at most one paced Q02 enqueue.
This is not a performance, certification, correlation, portfolio-admission,
deploy, or live decision.

## Approved Identity

- EA ID: `QM5_41172`
- slug: `wti-mpettitt-shift-tr`
- strategy ID: `MOP-PETTITT-WTI-MSHIFT-TREND-2026_S01`
- source ID: `MOP-PETTITT-WTI-MSHIFT-TREND-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41172_wti-mpettitt-shift-tr_card.md`
- host and traded symbol: `XTIUSD.DWX`, slot 0
- timeframe: D1
- risk for every backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The governed `farmctl reserve-ea-ids` allocator returned `reserved:true`,
`count:1`, and EA ID 41172 only after the source gate and canonical dedup scan
passed. Registry slug and strategy ID match the card.

## Source And Extraction Gate

Source approval commit: `978da98a90cc26d6e7a54fd6c2366718a960b631`.

Bounded records:

- complete governed Moskowitz-Ooi-Pedersen WTI source packet;
- Pettitt (1979), *Applied Statistics* 28(2), DOI `10.2307/2346729`, with the
  article body explicitly not claimed as completely read; and
- complete relevant `trend` 1.1.7 files at public mirror commit
  `d0ec3cf8b99b4f3226f5211f592955b85565721d`, including the exact rank-sum
  path, absolute maximum, and change-point location.

Evidence hashes:

- governed composite source packet:
  `A80A6F6C87C7FB1D5D9E4911A36C5CAFE7005319F4C844F0550B697577BA3C98`;
- retrieval receipt:
  `3518328F7A050B95C32D8349AB770D7DBE690CD603327C71087F9A4F5159DEAC`;
- canonical dedup receipt:
  `F06EAE90ED88E139C0CFA9BA2A4B02729F762DCDB5343EA6C931EEC54108679F`;
- approved card:
  `E31E558EE2CB8D22AD02553248B470E1D9ABA78B383AE417C5BDD0990CA182F6`.

`framework/scripts/skill_card_schema_lint.py` returned `status: ok`, no
forbidden-token hits, and no missing required sections before approval.

## Locked Strategy Contract

At the first executable D1 tick of each genuine new broker month:

1. Persist the normalized broker `yyyymm` before every fallible gate.
2. Select the latest D1 close in each of the immediately preceding thirteen
   consecutive completed broker months. Exclude the current month. Require
   positive, finite, pairwise-distinct closes, strict chronology, and newest
   endpoint staleness no greater than ten calendar days.
3. Assign the strict 1..13 rank permutation. For each `k=1..12`, compute
   `U[k]=2*sum(R[0..k-1])-14*k`; require even values in `[-42,42]`.
4. Let `U*=max(abs(U[k]))`. Require a positive value, exactly one maximizing
   `K`, and `4<=K<=9`.
5. Buy when signed `U[K]<0` because later ranks are higher; sell when
   `U[K]>0`. A tied/edge maximum or invalid path consumes the month flat.
6. Attach one frozen `3.5*ATR(20,D1)` hard stop, no target, and reject spread
   above 1,500 points. Own at most one slot-zero WTI position.
7. Exit on the first later broker month or after forty calendar days. Repair
   malformed, duplicate, wrong-side, wrong-symbol, wrong-magic,
   invalid-volume, or stopless owned exposure immediately.

News temporal mode is OFF, news compliance is NONE, legacy news is OFF, and
Friday close is OFF. Equal endpoints, average ranks, p-value gates, alternate
central bands, endpoint fallbacks, fitting, scale-in, grid, martingale, and
external runtime data are forbidden.

## Gate Findings

| Gate | Verdict | Basis |
|---|---|---|
| R1 | PASS | Complete-read peer-reviewed WTI carrier evidence, peer-reviewed Pettitt method record, and complete pinned CRAN implementation; exact trading conjunction disclosed as untested. |
| R2 | PASS | Clock, month reconstruction, strict ranks, twelve cumulative sums, maximum invariants, central band, side, attempt, risk, stop, and lifecycle are fully mechanical. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 archive and native MT5 state provide every runtime input; continuous-CFD basis remains a downstream risk. |
| R4 | PASS | Deterministic ranks, integer arithmetic, timestamps, ATR risk controls, and state only; no trained signal or banned runtime dependency. |

The card linter and R1-R4 consistency checks remain build preconditions. G0
does not transfer any expected performance or significance claim.

## Non-Duplicate Gate

The canonical fail-closed checker returned `CLEAN` across 4,671 registry rows,
1,322 cards, and 45 Strategy Wiki nodes.

Manual review establishes exact functional separation:

- Bartels uses squared adjacent rank distances and no split location;
- turning points use local extrema and endpoint direction;
- Foster-Stuart uses running records;
- this card uses the sign and location of the unique maximum cumulative
  rank-sum separation; and
- the two locked rank fixtures in the source approval produce opposite
  admission decisions versus Bartels and turning-point comparators.

The incumbent certified XNG sleeve is a two-day long-only oscillator pullback
on a different carrier and clock.

Verdict: `CLEAN_WTI_MONTHLY_PETTITT_UNIQUE_CENTRAL_SHIFT_CONTINUATION`.

## G0 Authorization And Kill Boundary

The card is approved for build because the source is durable, the rule is
mechanical, the identity is clean, the data route exists, and the proposed EA
uses only permitted structural arithmetic. It is not approved because an edge
or decorrelation has been observed.

Expected pre-result activity is four to eight completed positions/year. Retire
below four completed positions in any full post-warm-up year, at zero trades,
with nonpositive governed economics, any state/rank/split/side/risk defect,
nondeterminism, or any downstream gate failure. A failed result cannot be
rescued by changing the sample, central band, direction, risk, stop, hold,
carrier, or by adding a filter.

Before compile or Q02, the paced fleet must pass its current resource-capacity
check. If the binding backtest CPU ceiling is encountered, stop without tester
dispatch or terminal control and preserve the committed build state. Q02 may
be enqueued exactly once only after a current strict compile/Q01 PASS and
independent review PASS.

Excluded: manual backtests, live/demo/shadow/stress/optimization setfiles,
`T_Live`, AutoTrading, deploy or live manifests, portfolio-gate edits,
portfolio admission, correlation waiver, and any claim of certification.
