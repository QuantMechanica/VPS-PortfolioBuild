---
source_id: KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026
title: WTI exact five-year same-calendar raw-MAD-capped location
publisher: QuantMechanica governed composite of peer-reviewed trading sources
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_same_calendar_madcap5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
  - MOP-WTI-MADCAP-2026
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MOP-WTI-MADCAP-2026: 3038077FD9268BAAF923B0B3BE11E71126B48F92605B5726B86527D10E7D464B
created: 2026-08-30
created_by: Research
cards_extracted:
  - wti-samecal-madcap5
---

# WTI Exact Five-Year Same-Calendar MAD-Capped Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-30_wti_same_calendar_madcap5_source_approval.md`.
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
3. `strategy-seeds/sources/MOP-WTI-MADCAP-2026/source.md`, the approved
   governed extraction that fixes median/MAD centering, symmetric raw-MAD
   clipping, equal-weight retention, and claim limitations while disclosing
   the statistic as an untested QM mechanization.

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
five-observation MAD-capped estimate below, or a Darwinex continuous CFD.

## Bounded QM Mechanization

At the first processed D1 bar after a genuine normalized WTI broker-month
transition in year `Y` and month `M`, reconstruct the completed WTI log return
for month `M` in each exact year `Y-5` through `Y-1`. Require all five
observations. Compute the odd median and odd raw MAD, freeze symmetric bounds
at three raw MADs around the median, clip every original return into those
bounds, and trade the equal-weight five-value capped mean's sign for one
broker month.

The exact sample, single-CFD zero comparison, raw-MAD convention, cap
multiplier, endpoint normalization, fixed-dollar sizing, ATR hard stop, spread
ceiling, attempt ledger, and lifecycle are transparent QM choices. The source
does not test or validate those choices.

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

The five original returns remain in exact chronological year order. Sorting
is applied only to copies used for the median and MAD.

## Exact MAD-Cap Contract

For finite returns `r[0]..r[4]`, ordered from `Y-5` through `Y-1`:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]

lower = median - 3 * MAD
upper = median + 3 * MAD

capped[i] = min(upper, max(lower, r[i]))
location  = sum(capped[0..4]) / 5

signal = BUY  when location > +1e-12
         SELL when location < -1e-12
         FLAT otherwise or when any state is invalid
```

Reject a nonpositive MAD or any nonfinite input, deviation, bound, capped
value, sum, or location. Bounds are frozen before clipping. Clipping is
inclusive. Every observation remains in the five-term sum with equal weight.
The scale is raw MAD: no `1.4826` normalizer. There is no deletion, replacement
by an order statistic, refit, iteration, data-dependent divisor, fallback,
signal-magnitude sizing, or runtime parameter fit.

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
- Never scale in, pyramid, grid, martingale, partially close, trail, break
  even, optimize, read a runtime file/API, or consume portfolio state.

## Non-Duplicate Boundary

The corrected canonical receipt
`artifacts/qm5_wti_samecal_madcap5_preallocation_dedup_20260830.json`
scanned 4,731 registry identities, 1,369 cards, and 45 Strategy Wiki nodes. It
found no exact identity and only the expected `QM5_20099_wti-samecal` family
neighbor.

Manual review resolves the fuzzy match:

- `QM5_20099` averages raw same-calendar returns; it estimates no dispersion
  and does not clip shocks.
- `QM5_41055` reads the raw historical median only.
- `QM5_41199`, `QM5_41201`, `QM5_41202`, `QM5_41227`, `QM5_41228`,
  `QM5_41229`, `QM5_41230`, and `QM5_41231` use fixed trim,
  inclusive-pair pseudomedian, fixed endpoint Winsorization, chronological
  block median, shortest-three interval, trimean, midhinge, or bisquare
  reweighting. None creates median-centered raw-MAD bounds and retains all five
  clipped observations at equal weight.
- On sorted returns `[-0.20,-0.05,+0.01,+0.03,+0.19]`, this location is
  `+0.002` and buys, while the raw mean, middle-three trim, endpoint-Winsor,
  midhinge, shortest-three, inclusive-pair pseudomedian, and bisquare siblings
  sell; the trimean is flat.
- On sorted returns `[-0.15,-0.03,0,+0.03,+0.04]`, this location is `-0.01`
  and sells, while the median, trim, Winsor, trimean, midhinge, and
  pseudomedian siblings are flat and the shortest-three and bisquare siblings
  buy. Sign-reflected fixtures reverse both mappings.
- `QM5_20282_wti-madcap-mom` uses twelve adjacent recent monthly returns.
  This extraction samples one named calendar month across five separate
  years, so neither the information object nor formation clock is a horizon
  parameter port.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_RAW_MAD_CAPPED_EQUAL_WEIGHT_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: named authors,
  two DOI-bearing peer-reviewed trading papers, complete-read evidence,
  explicit WTI membership, and one governed exact MAD-cap arithmetic packet;
  exact five-sample conjunction untested.
- R2 `PASS`: month clock, uniform endpoint normalization, exact years, exact
  sample, odd median/MAD, raw scale, fixed cap, inclusive clipping, divisor,
  epsilon side, attempt, risk, spread, stop, and lifecycle are locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and native MT5 state supply every runtime input. History,
  roll, financing, gap, and futures-to-CFD basis risks remain binding.
- R4 `PASS`: completed prices, timestamps, logarithms, sorting, absolute
  deviation, clipping, comparisons, ATR controls, and execution state only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

The source supports testing a recurring WTI calendar carrier, not this robust
location's efficacy. Expected cadence is approximately ten to twelve completed
positions per full post-warm-up year. Q02 must retire on zero positions, fewer
than five in any full scored year, nonpositive governed economics, malformed
endpoints, a missing exact year, invalid MAD/bounds, incorrect clipping or
divisor, current-month leakage, repeated attempts, or wrong lifecycle. No
failure may be rescued by changing the sample, statistic, cap, direction,
carrier, stop, spread, hold, or retry contract.

Direct WTI and a recurring calendar clock target exposure outside the certified
XAU/SP500/NDX/XNG carrier set, but do not prove low correlation. Only unchanged
Q09 may measure portfolio overlap.

## Safety Boundary

This packet supports research, one V5 build, strict Q01, and one paced non-live
Q02 handoff only. It does not authorize a manual backtest, live/demo/shadow
preset, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
