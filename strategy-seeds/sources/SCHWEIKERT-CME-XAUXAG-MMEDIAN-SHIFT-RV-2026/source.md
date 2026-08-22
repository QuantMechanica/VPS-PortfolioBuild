---
source_id: SCHWEIKERT-CME-XAUXAG-MMEDIAN-SHIFT-RV-2026
title: XAU/XAG completed-month daily-close ratio-median shift reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_median_shift_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mmedian-shift-rv
---

# XAU/XAG Completed-Month Ratio-Median Shift Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed parent packets, both read completely before durable approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus the supplemental
   robust fractional-cointegration lineage recorded there. Its current
   SHA-256 is
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group's
   definition and tradable-relative-value framing of the gold/silver ratio.
   Its current SHA-256 is
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.

The OWNER source authorization is
`decisions/2026-08-22_xauxag_monthly_median_shift_reversion_source_approval.md`,
commit `65f571311`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

Schweikert documents a potentially state-dependent long-run relationship
between gold and silver prices and warns against assuming one immutable linear
equilibrium. The supplemental research recorded in the parent packet also
supports testing persistent but potentially fractional mean reversion. CME
defines the gold/silver ratio as gold price divided by silver price and treats
the two metals as an intermarket relative-value carrier with shared and
different economic drivers.

These findings support a falsifiable two-leg gold/silver relative-value
reversion experiment. They do not define completed calendar-month samples,
ordinary sample medians, comparison of two non-overlapping monthly locations,
a next-month contrarian hold, a unit hedge ratio, Darwinex CFDs, fixed-dollar
ATR risk, spread caps, restart persistence, or the QM portfolio. Every such
choice below is an explicit QM hypothesis; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of each broker-calendar month,
collect the immediately completed month and its consecutive parent month from
timestamp-identical `XAUUSD.DWX` and `XAGUSD.DWX` D1 closes. For every
synchronized completed session compute:

```text
r[d] = log(XAUUSD.DWX_close[d]) - log(XAGUSD.DWX_close[d])
```

Sort the ratios from each month independently. Define the ordinary sample
median `M` as the center ordered observation for an odd sample and the
arithmetic mean of the two center ordered observations for an even sample:

```text
M0 > M1  => newest completed-month ratio location shifted up
            SELL XAUUSD.DWX / BUY XAGUSD.DWX
M0 < M1  => newest completed-month ratio location shifted down
            BUY XAUUSD.DWX / SELL XAGUSD.DWX
M0 = M1  => FLAT
```

This is a contrarian fade of strict displacement in robust monthly ratio
location. It does not use a rolling mean, standard deviation, MAD scale,
z-score, regression, fitted beta, range endpoint, range width, current-month
confirmation, per-leg return rank, or displacement threshold. Equality and
invalid arithmetic remain flat; magnitude does not alter sizing.

The paired position follows the faded completed-month state until the first
tick of a later broker-calendar month. Month aggregation, the daily-close
ratio proxy, ordinary sample median, fixed unit log ratio, contrarian side,
equal-notional basket, continuous-CFD carrier, fixed-risk budget, ATR stops,
spread caps, consumed-attempt ledger, next-month exit, and stale repair are QM
choices. They are not attributed to either source.

## Exact Event Contract

All current decision-month data is excluded. The prior two packages must be
the two immediately preceding consecutive calendar months. Each package must
contain 17 through 23 unique, strictly increasing D1 sessions. Both legs must
have identical timestamps for every accepted session. Every close must be
positive and finite, every computed log ratio must be finite, and the odd/even
median arithmetic must remain finite.

One exact `yyyymm` attempt is persisted before aggregation, signal, news,
spread, quote, ATR, sizing, or order gates. Attachment later than 180 elapsed
minutes after the raw host D1 bar open consumes the month flat. An existing
owned package, orphan leg, or same-month entry deal blocks a new entry and
enters deterministic repair rather than silently stacking exposure.

The package targets one-to-one absolute entry notional after broker volume
normalization, with no more than 20 percent relative mismatch. The combined
frozen stop-loss risk is capped by one `RISK_FIXED=1000` budget. Each leg uses
one `3.5*ATR(20,D1)` hard stop and no take-profit. Entry spreads may not exceed
1,500 XAU points or 500 XAG points. Both news axes and Friday close are OFF.
The first tick of a later broker month closes the complete package; forty
calendar days is a stale repair only.

There is no rolling center, mean, standard deviation, MAD scale, fitted
coefficient, threshold, return rank, price range, volatility, volume, moving
average, season, weekday, inventory, event, external series, or prior-result
filter. There is no retry, target, trail, break-even move, partial close,
scale-in, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,593 registry identities,
1,272 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and one expected fuzzy family neighbor. Manual semantic review fixes the
load-bearing differences:

- `QM5_41103_xauxag-mrange-migrate-rv` requires both monthly ratio-range
  endpoints to migrate in the same direction. This extraction discards both
  endpoints and compares one ordinary median per month, so it can signal when
  ranges overlap, widen, contract, or migrate in mixed directions.
- `QM5_20263_xauxag-mad-rv` computes a rolling 63-D1 median and MAD score,
  requires a fresh threshold crossing, and exits an excursion near its rolling
  center. This extraction estimates no scale or threshold, uses two bounded
  non-overlapping calendar samples, and exits only on month lifecycle.
- `QM5_20057_xauxag-xmom1` follows a relative winner measured from two
  month-end closes. This extraction uses every valid synchronized daily close,
  compares robust ratio locations, and trades the inverse direction.
- `QM5_20157_xau-xag-ratio` computes a rolling mean/standard-deviation score
  and center exit; this extraction has none of those objects.
- `QM5_20161_xauxag-ols-rv` fits a residual and hedge coefficient; this
  extraction fits no parameter and uses one fixed unit log ratio.
- `QM5_41039_xauxag-mflow-div` compares monthly overnight and session return
  components rather than two monthly ratio-location distributions.
- Existing return-rank, seasonal, flow, empirical-tail, failed-break,
  variance, weekly-path, close-location, gap, and channel systems do not use
  this exact monthly median-shift state.

The exact XAU/XAG carrier, two consecutive completed calendar-month samples,
17-to-23 synchronized sessions each, independent ordinary medians, strict
comparison, contrarian equal-notional package, monthly attempt, and next-month
lifecycle are jointly load-bearing. Manual verdict:
`CLEAN_AFTER_EXPECTED_MONTHLY_RATIO_FAMILY_FUZZY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_MEDIAN_STATE_TRANSLATION_RISK`. One bounded source ID
  supplies lineage to named peer-reviewed authors, a DOI record, official
  exchange research, complete repository packets, and durable hashes; no
  performance claim transfers.
- R2: `PASS`. Exact clock, month adjacency, synchronized session membership,
  log-ratio construction, odd/even sample median, strict comparison, side,
  durable attempt, aggregate fixed risk, spreads, exit, and stale repair are
  mechanical.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply every
  runtime input. Q02 owns alignment, history, density, fill, cost, and CFD-
  basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed closes, logarithms, sorting,
  arithmetic, comparisons, ATR, spread, quotes, positions, deal history, and
  terminal state only; no trained model, external feed, banned signal, grid,
  martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The sources support testing a structural gold/silver relative-value reversion
carrier, not the efficacy of this monthly median proxy. Expected cadence is
approximately ten to twelve completed packages per full post-warm-up year,
but Q02 must measure it and retire below five. Q02 also owns baseline
economics; unchanged downstream gates alone own robustness and realized
correlation.

No failure may be rescued by accepting equality, changing calendar-month
membership, reading the current month, reversing the side, shortening the
hold, fitting a hedge ratio, adding a displacement threshold, or adding a
mean, scale, range, return, volatility, volume, season, weekday, moving-
average, inventory, event, or external-data filter.

## Safety Boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live logical-basket Q02 handoff only. It does not authorize a
manual backtest, live/demo/shadow/stress/optimization preset, `T_Live`,
AutoTrading, deploy or `T_Live` manifest, portfolio-gate change, portfolio
admission, correlation waiver, or decorrelation claim.
