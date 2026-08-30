---
source_id: KELOHARJU-MOP-WTI-SAMECAL-BISQUARE5-2026
title: WTI exact five-year same-calendar redescending bisquare location
publisher: QuantMechanica governed composite of peer-reviewed trading sources
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_same_calendar_bisquare5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
  - MOP-WTI-BISQUARE-2026
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MOP-WTI-BISQUARE-2026: 5B9B8452A816309AD0B8BC93830119B9C1DFE11860CECBBC617FFF25ABCA629B
created: 2026-08-30
created_by: Research
cards_extracted:
  - wti-samecal-bisquare5
---

# WTI Exact Five-Year Same-Calendar Bisquare Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-30_wti_same_calendar_bisquare5_source_approval.md`.
It authorizes one card, deterministic allocation, one branch-only non-live V5
build, strict Q01 validation, and one paced Q02 enqueue below the governed CPU
ceiling. It does not authorize a manual backtest or any live action.

The following repository packets were read completely under that decision:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, representing
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, plus the complete open 57-page NBER Working Paper
   20815.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, representing Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, plus the complete author-hosted 23-page
   published paper and its SHA-256 retrieval receipt.
3. `strategy-seeds/sources/MOP-WTI-BISQUARE-2026/source.md`, the approved
   governed extraction that fixes the bisquare scale, support, weight, and
   iteration conventions while disclosing them as an untested QM
   mechanization.

No inaccessible page, inferred table value, or ungoverned performance claim
is used.

## Trading-Source Findings Used

Keloharju, Linnainmaa, and Nyberg test whether historical returns for a named
calendar month recur when that month returns. Their commodity panel contains
24 futures, explicitly including crude oil, and requires at least five years
of history before a contract becomes eligible. The paper renews the
cross-sectional commodity position monthly.

Moskowitz, Ooi, and Pedersen test each instrument's own prior return as a
monthly directional state. Their commodity universe explicitly includes
NYMEX WTI crude. The paper supports own-return direction and monthly renewal
as a broad futures hypothesis.

Together those findings support testing whether WTI's returns from the same
named calendar month in exact prior years contain recurring directional
information. Neither paper tests a single-WTI zero comparison, the fixed
five-observation bisquare estimate below, or a Darwinex continuous CFD.

## Bounded QM Mechanization

At the first processed D1 bar after a genuine normalized WTI broker-month
transition in year `Y` and month `M`, reconstruct the completed WTI log return
for month `M` in each exact year `Y-5` through `Y-1`. Require all five
observations. Compute the raw median and raw median absolute deviation, freeze
the standard bisquare cutoff, execute exactly 32 re-centering updates, and
trade the final location's sign for one broker month.

The exact sample, single-CFD zero comparison, raw-MAD convention, scale
normalization, cutoff, fixed update count, epsilon, endpoint normalization,
fixed-dollar sizing, ATR hard stop, spread ceiling, attempt ledger, and
lifecycle are transparent QM choices. The source does not test or validate
those choices.

## Exact Calendar And Endpoint Contract

- Host and traded carrier: exact `XTIUSD.DWX`, D1, symbol slot zero.
- Decision time: the first executable host tick after a normalized broker
  month key changes.
- Target years: exactly `Y-5`, `Y-4`, `Y-3`, `Y-2`, and `Y-1`; no substitute
  year, shorter sample, or available-history compression.
- For each target `(year, month)`, require the last D1 close labelled in that
  month, the immediately preceding normalized month close, and at least one
  later D1 bar confirming completion.
- One uniform label rule applies to the entire copied D1 buffer: native broker
  labels when they contain at least two distinct months, otherwise the tested
  `+1` energy-label normalization. Mixed per-endpoint repair is forbidden.
- Endpoint timestamps must increase, prices must be positive and finite, and
  each completed return must be finite.

For each exact target year:

```text
r[year] = ln(close(year, M) / close(previous_month(year, M)))
```

The five original returns remain in exact chronological year order for the
return object. Sorting is applied only to copies used for the median and MAD.

## Exact Bisquare Contract

For finite returns `r[0]..r[4]`, ordered from `Y-5` through `Y-1`:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]
scale  = 1.4826 * MAD
cutoff = 4.685 * scale

mu[0] = median
for j = 0..31:
  u[i] = (r[i] - mu[j]) / cutoff
  w[i] = (1 - u[i]^2)^2 if abs(u[i]) < 1 else 0
  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])

signal = BUY  when mu[32] > +1e-12
         SELL when mu[32] < -1e-12
         FLAT otherwise or when any state is invalid
```

Reject a nonpositive median absolute deviation, scale, cutoff, total weight,
or nonfinite intermediate. The scale and cutoff freeze before the first
update. All 32 updates execute. The support comparison is strict. There is no
early-stop tolerance, return deletion or replacement, cutoff refit, fallback
center, magnitude sizing, or runtime parameter fit.

## Execution And Risk Contract

- Persist the current normalized `yyyymm` attempt before history, signal,
  news, spread, quote, ATR, sizing, or submission. No failure retries within
  the month.
- Close the prior package at the next normalized broker-month boundary before
  considering replacement risk. A 40-calendar-day guard closes only a
  survivor.
- Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
  exposure before entry logic.
- Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for Q02-Q10.
- Attach one frozen `3.5 * ATR(20,D1)` broker hard stop and no take-profit.
- Reject negative or crossed spreads and genuinely positive spreads above
  1,500 points.
- Lock current news temporal/compliance axes and the legacy news mode OFF.
  Disable Friday flattening because the monthly structural hold spans
  weekends.
- Never scale in, pyramid, grid, martingale, partially close, trail,
  break even, optimize, read a runtime file/API, or consume portfolio state.

## Non-Duplicate Boundary

The corrected canonical receipt
`artifacts/qm5_wti_samecal_bisquare5_preallocation_dedup_20260830.json`
scanned 4,730 registry identities, 1,368 cards, and 45 Strategy Wiki nodes.
It found no exact identity and only the expected broad family neighbor
`QM5_20099_wti-samecal`.

- `QM5_20099` uses the arithmetic mean of five to ten historical
  same-calendar returns. This packet requires all five exact years and a
  32-step redescending location.
- Same-calendar median, trim, Winsor, inclusive-pair, chronological-block,
  shortest-three, trimean, and midhinge EAs use different fixed functionals.
- `QM5_41204_wti-samecal-huber10` uses ten observations and Huber weights
  that remain positive for finite tail residuals; this packet uses five and
  assigns exactly zero weight at and beyond its frozen cutoff.
- `QM5_20286_wti-bisquare-mom` consumes twelve adjacent recent months. This
  packet consumes one named calendar month across five separate exact years.
  The observation object, structural clock, and warm-up are different.

For the sorted percent-return fixture `[-6,-1,-0.5,+0.5,+2]`, the locked
bisquare iteration finishes at approximately `+0.124940938` and buys. The raw
mean, median, middle-three mean, endpoint-Winsor mean, trimean, midhinge,
shortest-three mean, and inclusive-pair pseudomedian are all zero or negative.
The sign-reflected fixture produces the opposite mapping. Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FIXED_BISQUARE_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1: PASS with disclosed conjunction risk. Two named-author,
  DOI-bearing, peer-reviewed trading papers have complete-read evidence and
  explicit crude-oil/WTI membership. The exact bisquare translation is not a
  published trading result.
- R2: PASS. Calendar, endpoints, exact years, sample, return orientation,
  median/MAD, constants, support, weights, update count, side, attempt, risk,
  stop, spread, and exits are fixed before testing.
- R3: PASS with warm-up and basis risk. Registered `XTIUSD.DWX` D1 history and
  MT5-native calendar, quote, ATR, symbol, position, deal, and terminal state
  supply every runtime input.
- R4: PASS. Deterministic logarithm, sort, absolute deviation, and fixed
  arithmetic only; no trained output, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The sources support testing a recurring-calendar own-return WTI carrier, not
the efficacy of this fitted five-observation statistic. Q02 must retire the
card at zero trades, below five completed positions in any full post-warm-up
year, or on nonpositive governed economics. Downstream gates alone own
robustness and realized correlation. No failure may be rescued by changing
the sample, constants, cutoff, iteration count, direction, carrier, stop,
hold, spread, or retry contract.

## Safety Boundary

This packet supports one card, deterministic allocation, one non-live V5
build, strict compile/Q01, and one paced target-only Q02 handoff below the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress or
optimization preset, AutoTrading, `T_Live`, deploy manifest, T_Live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or a claim of
profitability or decorrelation.
