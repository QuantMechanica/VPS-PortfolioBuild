# QM5_41203 XAU/XAG Paired Same-Calendar Signed-Rank - G0 Decision

Date: 2026-08-29

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41203_xauxag-samecal-srank_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41203`
- slug: `xauxag-samecal-srank`
- strategy ID: `KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026_S01`
- source ID: `KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1, intended magic `412030000`
- companion / slot 1: exact `XAGUSD.DWX`, D1, intended magic `412030001`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41203` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026/source.md`,
SHA-256
`A4FB73EBF5AB394F64A6FCB0BA791FD10BD12496732AB7AE661068AC6A28486F`.
Its durable source approval is
`decisions/2026-08-29_xauxag_same_calendar_signed_rank_source_approval.md`,
committed before extraction as `0ca4b819a`.

R1 is `PASS_WITH_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK`. Complete-read
peer-reviewed lineages support same-calendar commodity returns and the
XAU/XAG cross-sectional carrier. Complete pinned R Core source and manual
define the one-sample signed-rank arithmetic. The exact paired CFD conjunction
is untested; no source performance, density, cost, hedge, CFD-equivalence, or
decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. At each genuine broker-month D1 transition, the card:

1. repairs owned exposure and consumes the month before fallible gates;
2. reconstructs synchronized completed XAU and XAG returns for the target
   month in exact years `Y-1..Y-10`, requiring five to ten paired samples;
3. forms `d=r_xau-r_xag`, rejects epsilon zeros and absolute ties, assigns
   strict ranks to `abs(d)`, and computes centered signed-rank score
   `S=2*V_plus-n(n+1)/2`;
4. buys XAU/sells XAG on positive `S`, reverses both legs on negative `S`, and
   consumes exact zero flat; and
5. renews at the next month boundary, with 40 days as survivor repair only.

One `RISK_FIXED=1000` budget is split equally by per-leg frozen
`3.5*ATR(20,D1)` stop risk. Both news axes, legacy news mode, and Friday close
are OFF. There is no parameter sweep or result-dependent rescue.

## Data And Determinism

R3 is `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`.
Registered synchronized XAU/XAG D1 history, broker time, quotes, contract
metadata, positions, deals, and terminal-persistent attempt state provide
every runtime field. Q02 must prove usable synchronized history, density,
fills, paired costs, and economics.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, sorting,
comparisons, and exact integer arithmetic; ATR is bounded risk plumbing. No
trained output, banned signal indicator, external runtime feed, grid,
martingale, scale-in, pyramid, or adaptive PnL fit exists.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xauxag_samecal_srank_preallocation_dedup_20260829.json`,
SHA-256
`C78FF4F0AF253B7E7889A0C1989A554F510DDB3D30B11497531B64E830871139`,
found no exact identity across 4,702 registry rows, 1,348 cards, and all 45
current Strategy Wiki nodes.

Manual review separates `QM5_20186`'s arithmetic mean of paired relative
returns and `QM5_41191`'s single-WTI signed-rank carrier. The vector
`[.01,.02,.03,.04,-.20]` makes this card buy while the mean basket sells; the
WTI neighbor cannot read or trade either paired-metal state. Recent-window
Mann-Whitney, rank-trend, ratio, residual, channel, and session neighbors use
different information objects.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_PAIRED_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_BASKET_RENEWAL`.

## Portfolio Intent And Falsification

The two opposite metal legs target relative monetary-gold versus industrial-
silver seasonality rather than the book's outright XAU return. This economic
distinction does not prove market neutrality or low portfolio correlation;
unchanged Q09 alone owns realized overlap.

Q02 retires on zero trades, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any calendar, endpoint,
synchronization, sample, zero/tie, rank, score, side, attempt, atomicity,
risk, stop, lifecycle, or determinism defect. No carrier, estimator, epsilon,
side, stop, hold, spread, or gate may change after results to rescue the
lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slots 0 and 1;
- one branch-only V5 EA build and basket manifest;
- one exact logical-basket D1 `RISK_FIXED` backtest setfile;
- strict compile and Q01 validation; and
- one paced Q02 enqueue if the active factory remains below its CPU ceiling.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate mutation, portfolio admission, or a correlation waiver.
