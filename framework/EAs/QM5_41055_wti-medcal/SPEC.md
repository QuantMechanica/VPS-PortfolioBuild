# QM5_41055 - WTI Median Same-Calendar Seasonality

Status: `SOURCE APPROVED; G0 NOT YET DECIDED; BUILD NOT STARTED`

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
- host: exact `XTIUSD.DWX`, D1
- planned slot: `0`
- planned deterministic magic: `410550000`

## Locked Candidate Boundary

At the first tradable D1 bar of each genuine broker month, reconstruct the
completed `XTIUSD.DWX` return for that same calendar month in each of the prior
ten years. Require at least five valid exact-calendar observations, sort them,
and use the center observation for an odd sample or the arithmetic mean of the
two center observations for an even sample.

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
This identity grants no build, Q02, or live authorization until the remaining
governed gates are satisfied.

