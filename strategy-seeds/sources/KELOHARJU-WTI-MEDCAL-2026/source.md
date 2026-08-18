---
source_id: KELOHARJU-WTI-MEDCAL-2026
title: WTI robust median same-calendar-month seasonality
publisher: The Journal of Finance / NBER
source_type: peer_reviewed_paper_bounded_robustness_translation
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-18_wti_median_same_calendar_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-18
created: 2026-08-18
created_by: Research+Development
parent_source_id: KELOHARJU-RETSEAS-2016
strategy_ids:
  - KELOHARJU-WTI-MEDCAL-2026_S01
cards_extracted:
  - QM5_41055_wti-medcal
---

# WTI Median Same-Calendar Source Packet

## Source Identity And Complete-Read Boundary

The canonical lineage is Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg,
Peter (2016), "Return Seasonalities," *The Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`. The reproducible open version is NBER
Working Paper 20815.

The governed packet
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` was read completely
before this bounded extraction. It records the complete 57-page NBER review,
including the model, commodity construction, robustness, tables, conclusions,
and references. It also records crude oil in the 24-future commodity panel and
the source's five-year minimum history rule.

The paper ranks commodities using the arithmetic mean of prior returns for the
same calendar month. It does not prescribe the median statistic below. That
statistic is a transparent QM robustness translation intended to stop an
isolated crude-oil shock year from controlling the sign of the entire seasonal
sample. No source result is attributed to it.

## Bounded Mechanization

`KELOHARJU-WTI-MEDCAL-2026_S01` is one predeclared direct-WTI falsification
package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- decide only on the first tradable D1 bar of a genuine broker month;
- reconstruct the completed return for that calendar month in each of the
  prior ten years as `ln(month_end_close / prior_month_end_close)`;
- require at least five valid exact-calendar observations;
- sort the valid observations; use the center return for an odd sample and the
  arithmetic mean of the two center returns for an even sample;
- buy for a median above `+1e-12`, sell for a median below `-1e-12`, and
  remain flat otherwise;
- close and, when a valid sign exists, renew at the next broker-month boundary;
- persist the `yyyymm` attempt before every fallible entry gate and never
  retry the month;
- use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
  and
- disable Friday flatten for the monthly hold, with a 35-calendar-day stale
  guard repairing only a survivor.

Runtime uses native MT5 D1 OHLC/timestamps, broker calendar, quotes, symbol
properties, ATR risk plumbing, positions, deal history, and terminal-global
attempt state. It uses no futures chain, roll file, inventory, volume, open
interest, COT, external API, CSV, trained output, optimizer artifact, or manual
signal.

## Exact Median Contract

For valid prior same-calendar log returns `r[0..n-1]`, with `5 <= n <= 10`:

```text
sort r ascending

if n is odd:
    seasonal_state = r[n / 2]
else:
    seasonal_state = (r[n / 2 - 1] + r[n / 2]) / 2

seasonal_state > +1e-12 => BUY XTIUSD.DWX
seasonal_state < -1e-12 => SELL XTIUSD.DWX
otherwise                => consume month flat
```

All endpoints precede the decision-month opening boundary. Current-month
open, high, low, close, and volume are forbidden from the signal. Signal
magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_RISK`: one named-author, peer-reviewed *Journal of
  Finance* lineage with DOI and durable complete-read evidence. The median and
  single-CFD reductions are explicit QM choices rather than source findings.
- R2 `PASS`: historical endpoints, sample bounds, median convention, sign,
  attempt, risk, stop, spread, and monthly exits are locked.
- R3 `PASS_WITH_HISTORY_WARMUP_RISK`: registered `XTIUSD.DWX` D1 supplies all
  runtime fields. Its 2017-start local history makes the five-year minimum a
  binding Q02 risk.
- R4 `PASS`: deterministic calendar, sorting, logarithm, and native execution
  arithmetic only; no ML, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, hedge, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,542 registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy identity. Manual
review separates the candidate from every same-calendar neighbor:

- `QM5_20099_wti-samecal` uses an arithmetic mean; this package uses the
  bounded sample median and forbids a mean fallback.
- `QM5_20136`, `QM5_20205`, `QM5_20251`, and `QM5_20137` retain the historical
  mean and add trend, prior-month, sign-breadth, or pullback conjunctions that
  are absent here.
- `QM5_13115` and `QM5_20190` rank two synchronized energy legs and require a
  paired basket.
- Fixed favorable-month WTI systems do not recompute a cross-year order
  statistic.
- `QM5_12567` is a daily long-only cumulative-RSI pullback.

The direct WTI carrier, exact prior-year same-calendar endpoints, ten-year
cap, five-sample floor, even/odd median convention, absolute sign, consumed
monthly attempt, and monthly renewal are jointly load-bearing.

Manual verdict:
`CLEAN_WTI_PRIOR_TEN_YEAR_SAME_CALENDAR_RETURN_MEDIAN_SIGN_MONTHLY_RENEWAL_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Claim, Kill, And Safety Boundary

The source supports recurring calendar information in a diversified rolling-
futures cross-section. It does not establish this median estimator, standalone
WTI profitability, continuous-CFD equivalence, post-2011 persistence, trade
density, costs, drawdown, or correlation with the certified book.

Expected cadence is approximately ten to twelve completed packages per full
post-warm-up year. Q02 must retire on zero trades, fewer than five per year,
nonpositive governed economics, wrong endpoints, current-month leakage, wrong
median arithmetic, retry, wrong lifecycle, nondeterminism, invalid fixed-risk
mode, or insufficient local history.

The OWNER mission and
`decisions/2026-08-18_wti_median_same_calendar_source_approval.md` authorize
exactly one card, deterministic ID and magic allocation, one branch-only
non-live build, strict Q01 validation, one `RISK_FIXED` backtest setfile, and
one paced target-only Q02 enqueue only below the tester and host-CPU ceilings.
They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization artifacts; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; correlation claims; and correlation
waivers.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | bounded peer-reviewed source extraction and median robustness translation | G0 | APPROVED_SOURCE |
