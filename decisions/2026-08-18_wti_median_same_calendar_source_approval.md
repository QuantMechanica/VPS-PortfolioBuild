# WTI Median Same-Calendar Seasonality - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests a new structural,
low-frequency commodity or energy sleeve that adds genuinely different
exposure to the certified XAU/SP500/NDX/XNG book, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `wti-medcal`
- proposed strategy ID: `KELOHARJU-WTI-MEDCAL-2026_S01`
- proposed source ID: `KELOHARJU-WTI-MEDCAL-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first tradable D1 bar of each genuine broker month
- state: median of up to ten prior completed WTI log returns for the same
  calendar month, requiring at least five observations
- lifecycle: trade the median sign for the new month, renew at the next month
  boundary, and repair only a survivor after 35 calendar days

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded source-of-record packet
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` was read completely
before this decision. It records a complete review of the 57-page open NBER
version of Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
*The Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`.

The source tests recurring same-calendar-month information in a broad futures
cross-section that explicitly includes crude oil. Its commodity construction
ranks assets by the arithmetic mean of prior returns for the matching calendar
month and requires at least five years of history.

The median estimator is an explicit QM robustness translation. The paper does
not test a historical median, a single-WTI absolute-sign portfolio, a
continuous Darwinex CFD, fixed cash risk, a broker-month attempt ledger, an
ATR stop, or this execution lifecycle. No source return, coefficient,
significance, density, cost, drawdown, CFD equivalence, decorrelation, or
portfolio result transfers.

## Locked Mechanic

On the first tradable `XTIUSD.DWX` D1 bar of each genuine broker month:

1. Close or repair any prior-month owned package before entry-only gates.
2. Persist the current `yyyymm` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates; never retry that month.
3. Reconstruct the completed return for the decision calendar month in each
   of the prior ten years as
   `ln(month_end_close / prior_month_end_close)`.
4. Require at least five positive, finite, exact-calendar observations.
5. Sort the valid returns ascending. For an odd count, use the center value;
   for an even count, use the arithmetic mean of the two center values.
6. Buy when the median is greater than `+1e-12`, sell when it is less than
   `-1e-12`, and consume the month flat otherwise. Signal magnitude never
   changes size.
7. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` package,
   a frozen `3.5 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no
   target.
8. Close at the first later broker-month D1 boundary. A 35-calendar-day stale
   guard repairs only a survivor.
9. Disable framework Friday flatten so the source-aligned monthly package can
   span weekends. Never retry, scale in, pyramid, grid, martingale, or hedge.

The exact same-calendar endpoint selection, five-sample floor, ten-year cap,
median convention, absolute sign, monthly attempt, fixed risk, hard stop, and
monthly lifecycle are load-bearing. No mean fallback, fixed favorable-month
list, recent-trend confirmation, volatility gate, inventory input, magnitude
threshold, or optimizer-selected filter is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_RISK`: one named-author, peer-reviewed *Journal of
  Finance* lineage with DOI and a durable complete-read record. The median and
  one-name CFD reductions are disclosed QM choices.
- R2 `PASS`: month endpoints, bounded sample, exact median convention,
  direction, attempt state, risk, stop, spread, and exits are deterministic.
- R3 `PASS_WITH_HISTORY_WARMUP_RISK`: registered `XTIUSD.DWX` D1 data supplies
  every runtime input. Local history begins in 2017, so the five-prior-year
  floor is a binding Q02 warm-up and density risk.
- R4 `PASS`: timestamps, OHLC, logarithms, sorting, ATR risk plumbing, quotes,
  positions, deal history, and terminal state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, hedge,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,542 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy identity for slug
`wti-medcal`, strategy ID `KELOHARJU-WTI-MEDCAL-2026_S01`, and mechanic
`single WTI historical same-calendar-month median-sign monthly renewal`.

Manual semantic review fixes the nearest boundaries:

- `QM5_20099_wti-samecal` uses the arithmetic mean of the valid historical
  returns. This candidate uses only their order statistic; one extreme oil
  shock can change the mean without changing the median, and neither statistic
  is a fallback for the other.
- `QM5_20136_wti-caltrend` requires the mean seasonal sign to agree with a
  completed 63-D1 trend sign. This candidate has no recent-trend state.
- `QM5_20205_wti-calmom1` and `QM5_20251_wti-cal-rsm` gate the historical mean
  with recent-return information. This candidate is unconditional after the
  median is valid.
- `QM5_20137_wti-seas-pb` trades only mean-seasonal/prior-month disagreement.
- Fixed-month WTI cards hard-code selected calendar directions rather than
  recomputing an order statistic from matching months across prior years.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a symmetric monthly WTI seasonal estimator.

Verdict:
`CLEAN_WTI_PRIOR_TEN_YEAR_SAME_CALENDAR_RETURN_MEDIAN_SIGN_MONTHLY_RENEWAL_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 retires on zero trades, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong
calendar endpoints, use of current-month prices, a mean instead of the locked
median, late or repeated entry, wrong monthly lifecycle, nondeterminism,
invalid risk mode, or unusable local history. A weak result may not be rescued
by switching estimator, adding a favorable-month list, threshold, trend,
volatility, inventory, or event filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the exact-path tester count and host CPU are below the governed ceilings.
At the ceiling, stop before queue mutation and record a non-live handoff.

