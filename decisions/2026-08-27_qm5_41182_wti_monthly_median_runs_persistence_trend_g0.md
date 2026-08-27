# QM5_41182 WTI Monthly Median-Runs Persistence Trend — G0 Decision

Date: 2026-08-27

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-27_wti_monthly_median_runs_persistence_trend_source_approval.md`.

Scope: approve one card, one registered V5 identity, one non-live build,
strict Q01 validation, independent review, and at most one paced Q02 enqueue.
This is not a performance, certification, correlation, portfolio-admission,
deploy, or live decision.

## Approved Identity

- EA ID: `QM5_41182`
- slug: `wti-median-runs-tr`
- strategy ID: `MOP-NIST-WTI-MEDRUN-TREND-2026_S01`
- source ID: `MOP-NIST-WTI-MEDRUN-TREND-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41182_wti-median-runs-tr_card.md`
- host and traded symbol: `XTIUSD.DWX`, slot 0
- timeframe: D1
- intended magic: `411820000`
- risk for every backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The governed `farmctl reserve-ea-ids` allocator returned `reserved:true`,
`count:1`, and EA ID 41182 after the durable source gate and corrected-root
canonical dedup scan passed. Registry slug and strategy ID match this card.

## Source And Extraction Gate

Source approval commit: `2ace42211`.

Bounded records:

- complete governed Moskowitz-Ooi-Pedersen WTI source packet, SHA-256
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
- complete official NIST/SEMATECH runs-test page, retrieved content SHA-256
  `9ACBE3A27118ABDF934FDD0EA75C4C1FFF52378BF7528271C0C751FB0531D374`;
- governed composite source packet, SHA-256
  `E1954B72A7E9F45BEA151DC1C18DFDA64C40D543C37CB22CF02E95F268147429`;
  and
- corrected-root canonical dedup receipt, SHA-256
  `7740FB213317764F76737EB97638FA3E6F5BCADC08CD8FE124708EAD6D6658B6`.

The card preserves citation roles and explicitly labels the exact trading
conjunction as untested. Both card linters must pass before build.

## Locked Strategy Contract

At the first executable D1 tick of each genuine new broker month:

1. Persist normalized broker `yyyymm` before every fallible gate.
2. Select the latest D1 close from each of the immediately preceding thirteen
   consecutive completed broker months. Require positive, finite,
   pairwise-distinct closes, strict chronology, and newest endpoint staleness
   no greater than ten days.
3. Assign strict ranks 1..13. Omit unique median rank seven, classify six
   lower ranks `-1` and six upper ranks `+1`, retain chronological order, and
   count consecutive same-sign runs `R`. Require exactly twelve signs, six of
   each sign, and `2<=R<=12`.
4. Buy when `R<=7` and the newest actual rank is above seven; sell when
   `R<=7` and it is below seven. A run count above seven or newest rank seven
   consumes the month flat. No p-value or fallback exists.
5. Attach one frozen `3.5*ATR(20,D1)` hard stop, no target, and reject spread
   above 1,500 points. Own at most one slot-zero WTI position under the locked
   fixed-risk contract.
6. Exit on the first later broker month or after forty calendar days. Repair
   malformed, duplicate, wrong-side, wrong-symbol, wrong-magic,
   invalid-volume, or stopless owned exposure immediately.

News temporal mode is OFF, news compliance is NONE, legacy news is OFF, and
Friday close is OFF. Signal-strength sizing, tie averaging, median bridging,
return-sign fallback, alternate thresholds, fitting, scale-in, grid,
martingale, and external runtime data are forbidden.

## Gate Findings

| Gate | Verdict | Basis |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed monthly WTI evidence and complete official NIST runs-method documentation; exact conjunction disclosed as untested. |
| R2 | PASS | Clock, endpoints, ranks, median omission, balance, run count, boundary, side, attempt, risk, stop, and lifecycle are mechanical. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered `XTIUSD.DWX` D1 archive and native MT5 state provide every runtime input. |
| R4 | PASS | Deterministic ranks, signs, counts, timestamps, ATR risk controls, and state only; no trained signal or prohibited dependency. |

No source efficacy, significance, density, performance, or decorrelation claim
transfers.

## Pre-Result Density

For thirteen no-tie ranks, exact enumeration over 924 six-low/six-high
orders and thirteen median insertion positions produces 6,744 qualifying
representations of 12,012. This equals 3,496,089,600 qualifying permutations
of 13!, split evenly by side, for rate `562/1001` and about 6.737 monthly
opportunities per random-order year.

This is a pre-market density identity used to respect the unchanged Q02
five-trades/year floor. It is not a probability model for WTI, a significance
threshold, or performance evidence.

## Non-Duplicate Gate

The first canonical checker invocation failed closed because its obsolete
default Wiki root was missing; no allocation followed. The corrected
invocation explicitly bound the current Company Reference vault and returned
`CLEAN` across 4,681 registry rows, 1,332 cards, and 45 Wiki nodes.

Manual functional separation is fixed:

- return-sign runs count the longest direction streak; median runs count all
  high/low price-level regimes after omitting the unique median;
- Mann-Kendall counts all 78 pair signs;
- Bartels weights squared adjacent rank distances;
- turning-point persistence counts local extrema; and
- Spearman weights squared time-rank displacement.

Rank fixture `[10,3,8,5,1,11,7,12,9,13,2,6,4]` sells only this candidate
among those five neighbors. Fixture
`[5,6,9,12,4,8,3,11,2,1,7,13,10]` is flat here while Bartels and turning-point
systems buy.

Verdict:
`CLEAN_WTI_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_REGIME_CONTINUATION`.

Certified `QM5_12567` is instead a long-only two-day XNG oscillator pullback;
it shares neither carrier, formation, direction symmetry, statistic, nor
lifecycle.

## G0 Authorization And Kill Boundary

The card is approved for build because the source is durable, the rule is
mechanical, the identity is clean, the native data route exists, and the
proposed EA uses permitted structural arithmetic. It is not approved because
an edge or decorrelation has been observed.

Q02 must retire at zero trades, below five completed positions in any full
post-warm-up year, with nonpositive governed economics, on any state/rank/
median/run/side/risk defect, nondeterminism, or any downstream gate failure. A
failed result cannot be rescued by changing the sample, threshold, direction,
risk, stop, hold, carrier, or adding a filter.

Before compile or Q02, the paced fleet must pass its current resource-capacity
check. If the binding backtest CPU ceiling is encountered, stop without tester
dispatch or terminal control and preserve the committed build state. Q02 may
be enqueued exactly once only after a current strict compile/Q01 PASS and
independent review PASS.

Excluded: manual backtests; live/demo/shadow/stress/optimization setfiles;
`T_Live`; AutoTrading; deploy or live manifests; portfolio-gate edits;
portfolio admission; correlation waiver; terminal control; and any claim of
certification or realized decorrelation.
