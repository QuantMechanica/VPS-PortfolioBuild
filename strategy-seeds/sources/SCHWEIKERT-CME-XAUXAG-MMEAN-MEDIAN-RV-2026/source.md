---
source_id: SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026
title: XAU/XAG completed-month log-ratio mean-median tail-bias reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_mean_median_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mmean-median-rv
---

# XAU/XAG Completed-Month Mean-Median Reversion Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed parent records. Both parent records were read completely before the
durable source approval was committed at `4a1957e0c`.

`strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` records
Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
from quantile cointegrating regressions," *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`, together with Yaya, Vo, and
Olayinka (2021), "Gold and silver prices, their stocks and market fear
gauges: Testing fractional cointegration using a robust approach,"
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`.

`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
official gold/silver ratio-spread material. CME defines the carrier as gold
price divided by silver price per troy ounce, describes it as an intermarket
spread, and notes different monetary/safe-haven versus industrial-cycle
drivers for the two metals.

The OWNER source authorization is
`decisions/2026-08-22_xauxag_monthly_mean_median_reversion_source_approval.md`.
No new online page, blocked content, inferred table value, or unrecorded
source is used.

## Source Findings Used

The peer-reviewed lineage supports a potentially state-dependent long-run
relationship between gold and silver rather than a fixed universal
equilibrium. It therefore supports a falsifiable relative-value carrier but
does not prove that every ratio displacement mean-reverts. CME supplies the
official ratio definition and supports treating the two instruments as one
intermarket-spread package.

Neither source defines a completed-calendar-month sample of synchronized
daily log-ratio closes, compares its arithmetic mean with its ordinary
median, treats their sign difference as a tail-bias state, maps that state to
a contrarian package, or tests a continuous-CFD implementation. Neither
source specifies equal notional, fixed-dollar ATR stops, the broker clock,
spread limits, persistent attempt state, or a one-month hold. Every such
choice below is an explicit QM hypothesis; no paper or CME performance result
transfers.

## Bounded QM Mechanization

On the first tradable exact `XAUUSD.DWX` D1 bar of each broker-calendar
month, reconstruct the immediately completed calendar month from exact
timestamp-matched `XAUUSD.DWX` and `XAGUSD.DWX` completed D1 closes. Require
17 through 23 unique, strictly increasing synchronized sessions and exclude
every current-month observation.

For every accepted session `d`, calculate:

```text
r[d] = log(XAU_close[d]) - log(XAG_close[d])

mean = sum(r[d]) / n

median(odd n)  = r_sorted[n / 2]
median(even n) = (r_sorted[n / 2 - 1] + r_sorted[n / 2]) / 2

mean > median => SELL XAU, BUY XAG
mean < median => BUY XAU, SELL XAG
mean = median => FLAT
```

The arithmetic mean moves farther than the median when a bounded sample has
more leverage from observations on one side. This card calls the strict
signed difference an internal tail-bias state; it does not call it a
standardized skewness estimator and does not infer a population moment. The
package fades the direction of that internal displacement for the next
broker month. Difference magnitude never changes eligibility, direction, or
risk.

The one-month sample, mean-versus-median functional, contrarian map,
continuous-CFD carrier, equal-notional target, fixed-risk package, ATR stops,
spread caps, consumed attempt, later-month exit, and stale guard are QM
choices. They are not attributed to the sources. No source alpha, Sharpe
ratio, drawdown, density, CFD equivalence, neutrality, or portfolio-
correlation statistic is imported.

## Exact Event Contract

The current decision month is derived from the exact host D1 bar timestamp
and broker time. The immediately completed `yyyymm` must be the calendar
predecessor across year boundaries. Entry evaluation is accepted only within
180 elapsed raw-session minutes of the first host D1 bar open in the new
month.

Within a fixed 40-bar buffer, every accepted observation must have identical
positive XAU/XAG close timestamps, exact completed-month membership, positive
finite closes, a unique timestamp, and strict chronological order after
normalization. The sample must contain 17 through 23 observations. Missing
companions, duplicate timestamps, invalid closes, more than 23 sessions,
fewer than 17 sessions, nonadjacent month arithmetic, or current-month
leakage is flat.

Compute the arithmetic mean from all ratio values. Sort only a copy for the
ordinary median. The even-sample median uses exactly the arithmetic mean of
indexes `n/2-1` and `n/2`; it is not a lower median. Mean and median must be
finite. Strict `mean>median` fades a relatively high-ratio tail; strict
`mean<median` fades a relatively low-ratio tail. Exact equality is flat.
There is no epsilon band, minimum displacement, standard deviation, MAD,
quantile, regression, hedge fit, z-score, threshold crossing, or signal-
strength sizing.

One exact decision `yyyymm` attempt is persisted before history, signal,
news, spread, quote, ATR, sizing, or order gates. Attachment outside the
grace window consumes the month flat. Existing owned exposure or a same-
magic entry deal recorded in the current broker month blocks a new entry.

The package targets one-to-one absolute entry notional. Both legs are rounded
down and the package is rejected if the resulting notional mismatch exceeds
20 percent. Each leg receives a frozen `3.5 * ATR(20,D1)` hard stop. Combined
normalized stop risk cannot exceed the single `RISK_FIXED=1000` budget.
There is no take-profit. Entry spread may not exceed 1,500 XAU points or 500
XAG points; modeled zero `.DWX` spread remains valid.

Both legs are submitted as one best-effort atomic package. If leg two fails,
leg one is flattened immediately. Orphaned, duplicated, same-side, stopless,
wrong-symbol, wrong-magic, later-month, stale, or notional-invalid exposure is
flattened before any new entry decision. The package closes on the first tick
whose broker `yyyymm` is later than its open month; forty calendar days is a
stale repair only.

Both news axes and Friday close are OFF. There is no retry, target, trail,
break-even move, partial close, scale-in, grid, martingale, pyramid, pending
entry, external file, API, futures chain, inventory, volume, options data,
trained output, or manual signal.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,598 registry identities,
1,277 repository cards, and 45 Strategy-Wiki nodes. It found no exact or
fuzzy identity. Receipt:
`artifacts/qm5_xauxag_mmean_median_rv_preallocation_dedup_20260822.json`.

The jointly load-bearing identity is the exact XAU/XAG carrier, one
synchronized completed calendar-month ratio-level sample, arithmetic mean,
ordinary odd/even median, strict internal mean-median displacement,
contrarian paired sides, equality flat, one consumed monthly attempt,
equal-notional aggregate fixed risk, and next-month hold.

It is not:

- `QM5_41104_xauxag-mmedian-shift-rv`, which compares robust locations across
  two non-overlapping months and never calculates a mean;
- `QM5_20263_xauxag-mad-rv`, which estimates rolling median/MAD scale and
  requires a standardized threshold crossing;
- `QM5_20268_xauxag-qtail-rv`, which uses fixed empirical decile tails over
  126 observations and a central-band exit;
- `QM5_20233_xauxag-skew-rank`, which calculates the standardized third
  moment of each metal's own returns over twelve complete months and ranks
  the two metals;
- `QM5_20157_xau-xag-ratio`, which uses a rolling 60-day mean/standard-
  deviation ratio score and an intramonth center exit;
- monthly ratio-median shift, range migration, weekly common-shock, streak,
  acceleration, retracement, overshoot, and close-location packages, whose
  information objects and state equations differ; or
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_INTERNAL_MEAN_MEDIAN_TAIL_BIAS_REVERSION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MEAN_MEDIAN_TAIL_TRANSLATION_RISK`: named peer-reviewed DOI
  lineage for a state-dependent gold/silver relation plus official CME ratio
  and spread-carrier material; the exact internal tail-bias rule is disclosed
  as an untested translation.
- R2 `PASS`: exact symbols, clock, month/sample membership, synchronization,
  log ratio, arithmetic mean, odd/even median, strict comparison, side map,
  attempt, notional, risk, stops, spreads, atomic repair, and lifecycle are
  fixed before results.
- R3 `PASS_WITH_CFD_BASIS_AND_RESIDUAL_BETA_RISK`: registered native XAU/XAG
  D1 plus MT5-native state supply every runtime input; Q02 owns history,
  density, costs, fills, financing, and continuous-CFD sufficiency.
- R4 `PASS`: closed-form timestamp, sort, logarithm, arithmetic, and framework
  state only; no ML, banned signal, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Frequency And Falsification

Exact arithmetic-mean/median equality should be rare in a valid 17-to-23-
observation ratio sample, so the declared expectation is ten to twelve
completed packages per full post-warm-up year. This is a density hypothesis,
not imported evidence. Q02 retires below the unchanged five-trades/year floor,
at zero trades or nonpositive governed economics, or on any clock, month,
synchronization, mean, median, side, attempt, notional, risk, atomicity,
lifecycle, or determinism defect.

No result may be rescued by adding an epsilon or magnitude threshold,
standardizing the difference, changing the direction or hold, altering the
sample bounds, fitting a hedge ratio, or adding volatility, volume, calendar,
event, moving-average, external-data, or prior-result filters.

## Implementation And Safety Boundary

The approved card may map the clock and locked inputs to No-Trade, month
reconstruction plus mean/median comparison to Trade Entry, malformed and
orphaned package repair to Trade Management, and later-month flattening to
Trade Close. The framework owns kill switch, registered magics, order
handling, and telemetry.

Only one logical-basket D1 backtest preset is permitted, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `ENV=backtest`. No live, demo,
shadow, stress, or optimization preset is authorized. Source approval forbids
manual backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live
manifest mutation, portfolio-gate changes, portfolio admission,
decorrelation claims, and correlation waivers. Strict Q01 must precede one
Q02 enqueue, and the fresh tester/host-CPU ceiling remains fail closed.
