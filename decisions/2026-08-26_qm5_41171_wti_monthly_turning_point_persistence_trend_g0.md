# QM5_41171 WTI Monthly Turning-Point Persistence Trend — G0 Decision

Date: 2026-08-26

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-26_wti_monthly_turning_point_persistence_trend_source_approval.md`.

Scope: approve one card, one registered V5 identity, one non-live build, strict
Q01 validation, independent review, and at most one paced Q02 enqueue. This is
not a performance, certification, correlation, portfolio-admission, deploy,
or live decision.

## Approved Identity

- EA ID: `QM5_41171`
- slug: `wti-mturnpoint-tr`
- strategy ID: `MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026_S01`
- source ID: `MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41171_wti-mturnpoint-tr_card.md`
- host and traded symbol: `XTIUSD.DWX`, slot 0
- timeframe: D1
- risk for every backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The deterministic allocator reserved row 41171 only after the source gate and
canonical dedup scan passed. Registry slug and strategy ID match the card.

## Source And Extraction Gate

Source approval commit: `4318078617763d524ce00bbda8e5ca51da0226af`.

Bounded records:

- complete governed Moskowitz-Ooi-Pedersen WTI source packet;
- Wallis and Moore (1941), JASA 36(215), DOI
  `10.1080/01621459.1941.10500577`, with the article body explicitly not
  claimed as completely read; and
- complete relevant `spgs` 1.0-4 files at public mirror commit
  `987257510f8b2a7ffe903d6b840021befbb4de58`, including the strict turning-
  point definition and iid null moments.

Evidence hashes:

- source packet:
  `91C2B08A1CEB8384CCEB8B1264E5CFF69FC590E544D052DB58C0C38CB19A2EBB`;
- source approval:
  `FE1AA3E5C2E4A79D2DD4EF6C52D4F1664C87BCE6C45D7CFE7B03D77C0D5153CE`;
- canonical dedup receipt:
  `371C5BF9BC108012F6FF8C53E6184CD234355995545A130E837DB7690C73B415`;
- approved card:
  `D192903525C42C3D4A537E797B0C5A81940C4BD1B6BEFE4AD130D7C1912CAF04`.

`framework/scripts/skill_card_schema_lint.py` returned `status: ok`, no
forbidden-token hits, and no missing required sections before approval.

## Locked Strategy Contract

At the first executable D1 tick of each genuine new broker month:

1. Persist the normalized broker `yyyymm` before every fallible gate.
2. Select the latest D1 close in each of the immediately preceding thirteen
   consecutive completed broker months. Exclude the current month. Require
   positive, finite, pairwise-distinct closes, strict chronology, and newest
   endpoint staleness no greater than ten calendar days.
3. For each interior endpoint `i=1..11`, count one turning point when it is a
   strict local peak or strict local trough. Require the count in `0..11`.
4. Qualify only when `3*TP<22`, the exact integer comparison to the iid null
   mean `2*(13-2)/3`; this is exactly `TP<=7`.
5. If qualified, buy when the newest endpoint exceeds the oldest and sell
   when it is below the oldest. Otherwise consume the month flat.
6. Attach one frozen `3.5*ATR(20,D1)` hard stop, no target, and reject spread
   above 1,500 points. Own at most one slot-zero WTI position.
7. Exit on the first later broker month or after forty calendar days. Repair
   malformed, duplicate, wrong-side, wrong-symbol, wrong-magic,
   invalid-volume, or stopless owned exposure immediately.

News temporal mode is OFF, news compliance is NONE, legacy news is OFF, and
Friday close is OFF. Equal endpoints, p-values, phase-duration inference,
alternate boundaries, fitting, magnitude fallbacks, filters, scale-in, grid,
martingale, and external runtime data are forbidden.

## Gate Findings

| Gate | Verdict | Basis |
|---|---|---|
| R1 | PASS | Complete-read peer-reviewed WTI carrier evidence, peer-reviewed Wallis-Moore method record, and complete pinned CRAN implementation; exact trading conjunction disclosed as untested. |
| R2 | PASS | Clock, month reconstruction, strict comparisons, count invariant, boundary, direction, attempt, risk, stop, and lifecycle are fully mechanical. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 archive and native MT5 state provide every runtime input; continuous-CFD basis remains a downstream risk. |
| R4 | PASS | Deterministic comparisons, integer arithmetic, timestamps, ATR risk controls, and state only; no trained signal or banned runtime dependency. |

The card linter and R1-R4 consistency checks remain build preconditions. G0
does not transfer any expected performance or significance claim.

## Non-Duplicate Gate

The canonical fail-closed checker returned `CLEAN` across 4,670 registry rows,
1,321 cards, and 45 Strategy Wiki nodes.

Manual review establishes exact functional separation:

- the WTI sign-run strategy retains longest same-sign return runs; this
  candidate counts every strict reversal over overlapping local triples;
- Mann-Kendall uses all 78 ordered endpoint pairs; this candidate uses only
  eleven adjacent triples;
- path efficiency preserves price magnitudes; this candidate discards
  magnitude after strict comparisons;
- Foster-Stuart counts running records; this candidate counts local extrema
  that need not be records;
- Bartels sums squared adjacent rank distances; this candidate assigns no
  ranks and counts only direction reversals; and
- the incumbent certified XNG sleeve is a two-day long-only oscillator
  pullback on a different carrier and clock.

The two locked rank fixtures in the source approval produce opposite
admission decisions versus Bartels, Mann-Kendall, Foster-Stuart, and sign-run
comparators. Changing the formation, comparison rule, count boundary,
endpoint direction, or clock destroys this decision identity.

Verdict: `CLEAN_WTI_MONTHLY_TURNING_POINT_COUNT_LT_NULL_MEAN_ENDPOINT_TREND`.

## G0 Authorization And Kill Boundary

The card is approved for build because the source is durable, the rule is
mechanical, the identity is clean, the data route exists, and the proposed EA
uses only permitted structural arithmetic. It is not approved because an edge
or decorrelation has been observed.

Expected pre-result activity is 5-8 completed positions/year, centered near
6/year. Retire at zero trades, below five completed positions in any full
post-warm-up year, nonpositive governed economics, any state/count/side/risk
defect, nondeterminism, or any downstream gate failure. A failed result cannot
be rescued by changing the sample, boundary, direction, risk, stop, hold,
carrier, or by adding a filter.

Before compile or Q02, the paced fleet must pass its current resource-capacity
check. If the binding backtest CPU ceiling is encountered, stop without
tester dispatch or terminal control and preserve the committed build state.
Q02 may be enqueued exactly once only after a current strict compile/Q01 PASS
and independent review PASS.

Excluded: manual backtests, live/demo/shadow/stress/optimization setfiles,
`T_Live`, AutoTrading, deploy or live manifests, portfolio-gate edits,
portfolio admission, correlation waiver, and any claim of certification.
