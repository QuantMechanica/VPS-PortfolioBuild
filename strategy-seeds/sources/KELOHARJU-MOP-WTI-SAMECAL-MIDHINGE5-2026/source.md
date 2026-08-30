---
source_id: KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026
title: WTI exact-five-year same-calendar fixed-midhinge seasonality extraction
publisher: QuantMechanica governed extraction of peer-reviewed return-seasonality and time-series-momentum sources
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_same_calendar_midhinge5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
  - MOP-WTI-TRIMEAN-2026
method_reference: NIST/SEMATECH e-Handbook of Statistical Methods, DOI 10.18434/M32189
created: 2026-08-30
created_by: Research+Development
cards_extracted:
  - wti-samecal-midhinge5
---

# WTI Exact-Five-Year Same-Calendar Fixed-Midhinge Source Packet

## Approved Sources Of Record

The structural calendar lineage is Keloharju, Matti; Linnainmaa, Juhani T.;
and Nyberg, Peter (2016), "Return Seasonalities," *The Journal of Finance*
71(4), 1557-1590, DOI `10.1111/jofi.12398`. The complete open NBER Working
Paper 20815 is represented by
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
`54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.

The own-return WTI lineage is Moskowitz, Tobias J.; Ooi, Yao Hua; and
Pedersen, Lasse Heje (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Its complete-paper review record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The governed order-statistic convention comes from the previously approved
packet `strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md`, SHA-256
`C44845663B3A12C24796E0D5337B23DB54250FF6CB0CE3AA6632BD191D5F8491`.
That packet fixes ascending return order and separates robust-location
arithmetic from the trading-paper result.

The complete NIST/SEMATECH e-Handbook pages "Measures of Location" and
"Box Plot" were read on 2026-08-30:

- https://www.itl.nist.gov/div898/handbook/eda/section3/eda351.htm
- https://www.itl.nist.gov/div898/handbook/eda/section3/boxplot.htm
- handbook DOI `10.18434/M32189`

NIST defines the lower and upper quartiles as the 25th and 75th percentiles,
describes the interval between them as the middle 50% of the observations,
and discusses tail-resistant location alternatives for non-normal or
heavy-tailed data. NIST does not name or test this card's exact five-item
hinge midpoint. The fixed `x[1]`, `x[3]`, and divisor-two convention is a QM
mechanization and no NIST performance claim transfers.

All three repository records and both bounded NIST pages were read completely
for candidate-specific source approval. That approval is
`decisions/2026-08-30_wti_same_calendar_midhinge5_source_approval.md`,
committed as `1a74921d2`.

## Source Findings Used

- Keloharju, Linnainmaa, and Nyberg test recurring same-calendar-month return
  information in a 24-commodity futures cross-section, explicitly including
  crude oil, renew monthly, and require at least five years of history.
- Moskowitz, Ooi, and Pedersen form monthly positions from each instrument's
  own past-return direction and explicitly include NYMEX WTI in their
  commodity universe.
- NIST identifies lower and upper quartiles as middle-50% boundaries and
  documents the motivation for less tail-sensitive location summaries.
- The governed order-statistic packet fixes ascending-sort discipline and a
  strict no-transfer boundary for untested robust arithmetic.

Those findings support a falsifiable WTI recurring-calendar middle-50%
location test. They do not establish a five-sample same-calendar midhinge, a
standalone WTI result, or continuous-CFD efficacy.

## Bounded QM Mechanization

At the first executable D1 tick of a genuine normalized broker-month
transition `(Y,M)`, reconstruct the completed `XTIUSD.DWX` log return for
calendar month `M` in each exact year `Y-5..Y-1`. All five observations are
mandatory. Sort the five returns ascending and compute the fixed odd-sample
hinge midpoint:

```text
x = sort_ascending(r[Y-5], r[Y-4], r[Y-3], r[Y-2], r[Y-1])

lower_hinge = x[1]
upper_hinge = x[3]
location    = (lower_hinge + upper_hinge) / 2

location > +1e-12 => BUY XTIUSD.DWX
location < -1e-12 => SELL XTIUSD.DWX
otherwise          => FLAT
```

The position closes and may be replaced at the next genuine normalized
broker-month boundary. One attempt is persisted before any fallible entry
gate. The baseline uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, a frozen `3.5 * ATR(20,D1)` hard stop, no target, a
1,500-point WTI spread ceiling, and a 40-calendar-day survivor repair. Both
current news axes and legacy news mode are OFF, and Friday flattening is OFF.

The exact five years, odd-sample hinge convention, deliberate exclusion of
the median and extremes, continuous-CFD carrier, broker-month endpoint
reconstruction, one-attempt ledger, fixed-dollar risk, ATR stop, spread
ceiling, and survivor repair are transparent QM choices. No paper or NIST
page prescribes this conjunction.

## Exact Statistical Contract

For five positive finite completed same-calendar-month returns, sorted
ascending as `x[0]..x[4]`:

```text
Q1 = x[1]
Q3 = x[3]
H  = (Q1 + Q3) / 2
```

The extreme observations `x[0]` and `x[4]` and the exact median `x[2]` do not
enter the numeric location after establishing the ordering. Each hinge has
weight one-half. The hinges are single order statistics, not interpolated
quantiles. The current decision month supplies no endpoint.

There is no fallback to a raw mean, ordinary median, middle-three mean,
Winsorized mean, trimean, pairwise pseudomedian, Huber location,
shortest-half interval, signed-rank score, t-score, sign count, recency
weighting, regime comparison, contiguous-return trend, price slope, moving
average, oscillator, fixed-month direction, external series, or prior
pipeline result.

## Calendar And Endpoint Contract

- Accept exactly one uniform native or `+1` D1 energy-label convention for
  the host series and apply it to every historical endpoint.
- For each exact year, find the last normalized D1 close in the month before
  `M` and the last normalized D1 close in `M`; require a later confirming bar
  so the month is complete.
- Require adjacent calendar-month endpoints, positive finite closes, exact
  year identity, and all five separate years. No nearest-year substitution,
  compressed missing year, partial sample, or current-month price is allowed.
- Persist broker `yyyymm` before history, signal, news, spread, quote, ATR,
  sizing, margin, or submission. Any flat or invalid outcome consumes the
  month.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_midhinge5_preallocation_dedup_20260830.json`,
SHA-256
`73AE30B9E4B499FC0D09175B2AC3EF8E95025B27C6620A2FB4203EFE32576802`,
scanned 4,729 EA-registry identities, 1,367 cards, and 45 Strategy Wiki nodes.
It found no exact identity and surfaced only the expected fuzzy raw-mean
same-calendar neighbor `QM5_20099_wti-samecal`.

Manual executable separation is fixed before allocation:

- `[-6,-4,-3,+5,+5.5]` yields midhinge `+0.5`, full mean `-0.5`, median
  `-3`, middle-three mean `-0.6666666667`, one-per-tail Winsor mean `-0.2`,
  trimean `-1.25`, and shortest-three midmean `-4.3333333333`. The candidate
  buys while every named sibling sells.
- `[-6,-5,+2,+3,+12]` yields midhinge `-1`, full mean `+1.2`, median `+2`,
  and trimean `+0.5`. The candidate sells while those three siblings buy.
- `QM5_41055` and `QM5_20099` use an ordinary median or full mean.
  `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use a fixed
  equal-weight trim, fifteen inclusive pair averages, endpoint Winsorization,
  or a ten-sample iterative Huber location. Their state and arithmetic differ.
- `QM5_41227` preserves year order inside four overlapping two-year means;
  `QM5_41228` selects a data-dependent shortest three-value interval; and
  `QM5_41229` weights the median at one-half. This candidate always reads
  fixed sorted indexes `1` and `3`, each at one-half, and discards `x[2]`.
- `QM5_20283_wti-trimean-mom` consumes twelve adjacent recent months and six
  even-sample order statistics. This candidate consumes five observations of
  one named month across separate exact years and two odd-sample hinges. It
  is not a horizon parameter port.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FIXED_MIDHINGE_SIGN_MONTHLY_SLEEVE`.

## Runtime Guardrails

- Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, ATR, spread, symbol
  metadata, quotes, positions, deals, margin, and terminal-global attempt
  state only.
- No futures curve, contract chain, storage, inventory, volume, open interest,
  COT, EIA, weather, external file, API, optimizer output, trained signal,
  grid, martingale, scale-in, or pyramiding.
- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`. No live, demo, shadow, stress, or optimization preset.
- Friday close is disabled for the monthly hold; next-month rollover, hard
  stop, malformed-exposure repair, and 40-day survivor repair remain.

## Reputable-Source Criteria

- R1: `PASS_WITH_HINGE_ONLY_AND_SINGLE_CFD_TRANSLATION_RISK`. Two
  complete-read, DOI-bearing, peer-reviewed trading papers support the
  information clock, WTI membership, own-return direction, and monthly
  lifecycle. NIST supplies official quartile, middle-50%, and robust-location
  context. The exact WTI conjunction is explicitly untested.
- R2: `PASS`. Calendar endpoints, exact sample, sort, hinge indexes, divisor,
  epsilon, side, attempt, fixed risk, stop, spread, rollover, and repair are
  mechanical and locked.
- R3: `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered native WTI D1 history supplies every signal input; history,
  session labels, rolls, financing, gaps, and CFD basis remain binding.
- R4: `PASS`. Deterministic timestamps, log returns, sorting, averaging, ATR
  risk controls, and native execution state only. No ML or banned signal
  indicator.

## Claim, Kill, And Safety Boundary

The sources support testing a recurring-calendar WTI own-return carrier, not
the efficacy of this midhinge rule. Q02 must retire the card below five
completed packages in any full post-warm-up year or on nonpositive governed
economics. Wrong endpoint years, partial samples, current-month leakage,
incorrect hinge indexes/divisor, accidental median inclusion, repeated
attempts, missing stops, invalid risk, or nondeterminism are hard failures. No
failure may be rescued by changing the sample, estimator, direction, carrier,
stop, hold, spread cap, or retry contract.

Direct WTI is intended to diversify the certified XAU/SP500/NDX/XNG book, but
that is a construction objective only. Q09 alone may determine realized
portfolio correlation.

This packet supports research, one branch-only V5 build, strict compile/Q01,
and one paced non-live Q02 handoff subject to CPU capacity. It does not
authorize a manual tester, live artifact, `T_Live`, AutoTrading, deploy or
T_Live manifest, portfolio-gate change, portfolio admission, correlation
waiver, or claim that the sleeve is already uncorrelated.
