# QM5_41169 WTI Monthly Foster-Stuart Record-Count Trend — G0 Authorization

Date: 2026-08-26

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced Q02 enqueue under the current factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`. It asks for one genuinely new structural,
low-frequency commodity/energy sleeve, permits a WTI trend/seasonality edge,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Approved Identity

- EA: `QM5_41169`
- slug: `wti-foster-record-tr`
- strategy ID: `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01`
- source ID: `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026`
- slot 0: `XTIUSD.DWX`, D1, intended magic `411690000`

The ID was not inferred. The atomic command
`farmctl reserve-ea-ids --strategy-id
MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01 --slug
wti-foster-record-tr` returned `reserved:true`, `count:1`, and EA ID `41169`
on 2026-08-26. Magic allocation remains a separate deterministic build
preflight after the EA directory exists.

## Source And Extraction Gate

The source of record is
`strategy-seeds/sources/MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026/source.md`,
SHA-256 `DCF1A2C5F22CB6E0F6E337E7EF4784851A63D2DA80864FE9A4EB252E66D2E6A4`.
Its durable source approval is
`decisions/2026-08-26_wti_monthly_foster_stuart_record_count_trend_source_approval.md`,
committed as `97221b5cc` before card extraction.

The bounded packet joins one canonical trading lineage and one statistical
method lineage:

- Moskowitz, Ooi, and Pedersen (2012), complete governed paper read, supplies
  monthly own-price continuation, monthly renewal, and explicit NYMEX WTI.
- Foster and Stuart (1954), official peer-reviewed record, supplies
  distribution-free upper/lower-record trend-in-location lineage.
- `RecordTest` commit `463cca629cec54ed58dfe0f03140d29be6c8f2aa`,
  companion to a peer-reviewed *Journal of Statistical Software* paper,
  supplies the complete public forward-`d` formula and strict record
  definitions. Its relevant files were read completely through the public
  GitHub API route with durable blob and SHA-256 evidence.

The source does not test the exact thirteen-endpoint `d=2` WTI CFD rule. No
source performance, frequency, significance, CFD-equivalence, or correlation
claim transfers.

## Locked Strategy Contract

At the first executable D1 tick of each genuine new broker month, consume the
month and reconstruct the latest close in each of the immediately prior
thirteen consecutive broker months. Starting from the oldest close, count a
strict forward upper record when a close exceeds every prior close and a
strict forward lower record when it is below every prior close. Equality is
neutral. Require `upper + lower + neutral = 12` and compute
`d = upper - lower`.

- buy WTI only when `d >= 2`;
- sell WTI only when `d <= -2`;
- consume `abs(d) < 2` or invalid state flat;
- hold through Fridays until the next normalized broker month, with a
  forty-day stale repair;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
  1,500-point spread ceiling.

Both news axes, legacy news, and Friday close are OFF. There is no p-value,
backward-record statistic, weak-record mode, endpoint fallback, slope,
correlation, moving average, oscillator, external feed, retry, scale-in,
grid, martingale, or pyramid.

## Gate Findings

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence; official peer-reviewed Foster-Stuart
  record; and complete exact-method files from a peer-reviewed public
  statistical package. The exact trading conjunction is untested.
- R2 `PASS`: thirteen consecutive completed endpoints, strict record
  frontiers, count conservation, `d=2`, direction, consumed attempt, fixed
  risk, stop, spread cap, and lifecycle are exact.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input.
- R4 `PASS`: deterministic comparisons, integer counts, calendar, ATR risk,
  and execution state only; no trained output or banned signal indicator.

## Non-Duplicate Gate

The canonical receipt
`artifacts/qm5_wti_foster_record_tr_preallocation_dedup_20260826.json`,
SHA-256 `BB0661A74BC9F28E2D292DDF49A01E131289A0054DB895B3FB76F54255AF7891`,
is `CLEAN` across 4,668 registry rows, 1,319 cards, and 45 Strategy Wiki
nodes.

Manual functional review confirms the statistic is not an endpoint horizon,
Mann-Kendall all-pairs score, OLS/robust slope, Cox-Stuart fixed-pair count,
quarterly vote, Spearman zero crossing, or within-month path rule. The two
locked rank vectors in the source approval make this rule buy while those
neighbors do not and make those neighbors buy while this rule stays flat.

The direct WTI carrier is absent from the stated XAU/SP500/NDX/XNG book and
the record-frontier path driver is different from certified
`QM5_12567_cum-rsi2-commodity`. Those facts motivate testing only. Q09 alone
owns realized correlation.

## G0 Authorization And Kill Boundary

The card may be copied into the EA directory and implemented without changing
its statistic, threshold, direction, risk, stop, attempt, or lifecycle. Q01
must prove schema, registry, resolver, compile, and reference-vector
correctness before one Q02 row is enqueued.

The exact no-tie rank-permutation density prior is 47.5975508224%, or
5.7117060987 qualifying monthly paths/year. Q02 must retire below five
completed trades in any full post-warm-up year, on zero trades, nonpositive
governed economics, or any endpoint, record, count, side, attempt, risk, or
lifecycle defect. No failed result may be rescued under the same identity.

This authorization excludes a manual backtest, terminal dispatch above the
CPU ceiling, live/demo/shadow/stress/optimization presets, `T_Live`,
AutoTrading, deploy/live manifests, portfolio-gate changes, portfolio
admission, correlation waivers, and terminal process control.
