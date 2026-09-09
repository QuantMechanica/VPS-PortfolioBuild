# QM5_41406 WTI summer two-week agreement — build and Q02 enqueue

Recorded: 2026-09-10 01:14 Europe/Berlin

## Outcome

`QM5_41406_wti-summer-w2agree` is a new approved and allocated WTI D1
candidate. It trades only June-October Monday-anchored weeks and continues
only when the two immediately completed adjacent weeks have the same strict
open-to-close log-return sign. This is disjoint from the existing WTI winter
agreement and uses a different carrier from the XNG summer sibling.

Governed compile item `ee85cdf5-53f6-4d7e-b28d-e13d70719d05` finished
`COMPILE_OK` with zero errors, zero warnings, and build check `PASS`. The EX5
SHA-256 is
`5fffc93ba73dde8d8f02bd2947bf461b39c450d8cd3e6f5f51ce590d7c624d9e`.

The exact fixed-risk `XTIUSD.DWX` D1 intake dry run was eligible. A fresh
five-sample CPU window measured `26, 50, 91, 84, 91` percent: average `68.4%`
and maximum `91%`, both strictly below the `97%` ceiling. Q02 work item
`120d4922-061b-4d25-ab8b-80e022c96259` was therefore enqueued and was pending
at the receipt snapshot.

## Build And Guard Evidence

- Source: complete governed reads of peer-reviewed WTI May-October
  seasonality and peer-reviewed commodity own-return continuation lineages;
  the weekly conjunction is explicitly an untested QM translation.
- Dedup: no exact identity; manual review separates the disjoint WTI winter
  agreement, XNG summer/winter siblings, and year-round WTI weekly relatives.
- Registry: EA 41406, slot 0, `XTIUSD.DWX`, magic `414060000`.
- PACER audit: exit zero and zero `EA_FRAMEWORK_INPUT_PINNED` hits before the
  compile enqueue. Framework RNG, news, and Friday inputs are not compared;
  stress rejection receives only finite/range validation.
- Reference harness: 15 tests pass.
- Backtest preset: `RISK_FIXED=1000`, `RISK_PERCENT=0`, no live preset.

## Boundary

No manual backtest, optimization, portfolio-gate edit, portfolio admission,
correlation waiver, deploy/live manifest change, `T_Live`, AutoTrading, or
terminal-control action occurred. Q02 and later gates own economics and
realized correlation.
