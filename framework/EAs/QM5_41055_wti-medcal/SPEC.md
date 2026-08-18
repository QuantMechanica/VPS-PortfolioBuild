# QM5_41055 - WTI Median Same-Calendar Seasonality

Status: `G0 APPROVED; Q01 PASS; Q02 CAPACITY CHECK PENDING`

## Identity

- EA ID: `QM5_41055`
- slug: `wti-medcal`
- strategy ID: `KELOHARJU-WTI-MEDCAL-2026_S01`
- source ID: `KELOHARJU-WTI-MEDCAL-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-WTI-MEDCAL-2026/source.md`
- source approval:
  `decisions/2026-08-18_wti_median_same_calendar_source_approval.md`
- source approval commit: `5c51e1248`
- approved card:
  `strategy-seeds/cards/approved/QM5_41055_wti-medcal_card.md`
- G0 decision: `decisions/2026-08-18_wti_median_same_calendar_g0.md`
- EA registry allocation commit: `084ebfac5`
- magic allocation commit: `25c55d920`
- host: exact `XTIUSD.DWX`, D1
- planned slot: `0`
- planned deterministic magic: `410550000`

## Locked Candidate Boundary

At the first tradable D1 bar of each genuine broker month, reconstruct the
completed `XTIUSD.DWX` return for that same calendar month in each of the prior
ten years. Require at least five valid exact-calendar observations, sort them,
and use the center observation for an odd sample or the arithmetic mean of the
two center observations for an even sample.

Accept only native same-day D1 labels or one uniform `+1` calendar-day energy
offset, require the normalized current D1 date to equal broker date, and apply
that one offset to every historical endpoint.

Trade the median sign only: positive above `1e-12` buys WTI, negative below
`-1e-12` sells WTI, and a numerical tie consumes the month flat. The signal
may not use current-month prices, fall back to an arithmetic mean, hard-code
favorable months, or add a recent-trend, volatility, inventory, or event gate.

The planned non-live build uses one consumed `yyyymm` attempt, monthly renewal,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5 * ATR(20,D1)` hard stop, no target, a 1,500-point spread ceiling, and a
35-calendar-day stale repair. Framework Friday flatten is disabled for the
source-aligned monthly hold. No retry, scale-in, grid, martingale, hedge, or
pyramid is permitted.

## Duplicate Boundary

The canonical checker scanned 4,542 EA rows and 625 root cards and returned
`CLEAN`. Manual review separates the median order-statistic from the mean-based
`QM5_20099_wti-samecal`, the mean-plus-trend or mean-plus-return conjunctions,
paired energy ranks, fixed favorable-month systems, and the incumbent
`QM5_12567` cumulative-RSI pullback.

Verdict:
`CLEAN_WTI_PRIOR_TEN_YEAR_SAME_CALENDAR_RETURN_MEDIAN_SIGN_MONTHLY_RENEWAL_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Allocation State

`QM5_41055` is the deterministic successor to the maximum registered numeric
EA ID `41054` observed immediately before allocation. The directory exists
before magic allocation, as required by the resolver regeneration contract.
G0 authorizes exactly the non-live implementation in the approved card, one
fixed-risk backtest setfile, strict Q01 validation, and one paced target-only
Q02 enqueue below the governed tester and CPU ceilings. It grants no live,
portfolio, or deployment authority.

## Implementation State

The EA, independent reference suite, approved-card build copy, and sole
`RISK_FIXED` D1 backtest preset are implemented. The source uses one bounded
historical D1 scan only after a genuine monthly bar edge, validates uniform
energy-label normalization and adjacent month identity, and computes the
sample median without a full-sample mean fallback. Strict Q01 evidence is
complete before any Q02 capacity check.

- source implementation commit: `d51ed3bb5`
- independent reference suite: 13 tests `PASS`
- card schema lint: `PASS`, both byte-identical copies
- symbol-scope validation: `SINGLE_SYMBOL_OK`
- strict MetaEditor compile: `PASS`, 0 errors, 0 warnings
- compile log:
  `framework/build/compile/20260818_004637/QM5_41055_wti-medcal.compile.log`
- targeted build check: `PASS`, 0 failures, 0 warnings
- build report: `D:/QM/reports/framework/21/build_check_20260818_004637.json`
- static P1: `PASS`
- P1 report:
  `D:/QM/reports/pipeline/QM5_41055/P1/P1_QM5_41055_result.json`
