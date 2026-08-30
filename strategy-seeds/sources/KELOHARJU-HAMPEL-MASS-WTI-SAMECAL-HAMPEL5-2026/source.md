---
source_id: KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026
title: WTI exact five-year same-calendar Hampel redescending location
publisher: QuantMechanica governed composite of peer-reviewed trading sources and primary statistical documentation
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_same_calendar_hampel5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-30
created_by: Research
cards_extracted:
  - wti-samecal-hampel5
---

# WTI Exact-Five-Year Same-Calendar Hampel Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-30_wti_same_calendar_hampel5_source_approval.md` at commit
`b95b732c9`. It authorizes one card, deterministic allocation, one
branch-only non-live V5 build, strict Q01 validation, and one paced Q02
enqueue below the governed CPU ceiling. It does not authorize a manual
backtest or live action.

The following records were read completely under that decision:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, representing
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, plus the complete open 57-page NBER Working Paper
   20815.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, representing Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, plus the complete author-hosted 23-page
   published paper and its durable retrieval hash.
3. The relevant `rlm` and `psi.hampel` entries in the author-maintained CRAN
   `MASS` manual at
   `https://stat.ethz.ch/CRAN/web/packages/MASS/MASS.pdf`, including the
   named references Hampel, Ronchetti, Rousseeuw, and Stahel (1986),
   *Robust Statistics: The Approach Based on Influence Functions*, Wiley,
   and Venables and Ripley (2002), *Modern Applied Statistics with S*,
   fourth edition, Springer.
4. The complete relevant `psi.hampel` implementation and the surrounding
   IWLS call convention in author-maintained `MASS/R/rlm.R`, reviewed at
   `https://rdrr.io/cran/MASS/src/R/rlm.R`. The implementation returns
   `psi(u)/u` for derivative mode zero and fixes the default constants
   `a=2`, `b=4`, and `c=8`.

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

Together those findings support falsifying whether WTI's returns from the
same named calendar month in exact prior years contain recurring directional
information. Neither paper tests a single-WTI zero comparison, the fixed
five-observation Hampel estimate below, or a Darwinex continuous CFD.

## Statistical-Source Findings Used

The CRAN `MASS` documentation identifies `psi.hampel` as a supplied
redescending proposal for robust M estimation. It documents:

- default constants `a=2`, `b=4`, and `c=8`;
- iteratively reweighted least squares as the fitting mechanism;
- a rescaled-MAD option for scale; and
- multiple-local-minimum risk for Hampel and bisquare redescending scores.

The source implementation makes the derivative-zero result an observation
weight `psi(u)/u`. With `U=min(abs(u)+1e-50,c)`, it returns:

```text
1                              for U <= a
a/U                            for a < U <= b
a*(c-U)/((c-b)*U)              for b < U <= c
```

At `U=c` the last expression is zero. Values whose uncapped absolute residual
is at least `c` therefore have zero weight. The tiny implementation guard only
defines the removable `u=0` division and does not alter its exact unit weight.

The source does not prescribe this trading sample, exact initialization,
fixed 32-update budget, or frozen-scale choice. Those remain governed QM
mechanization decisions.

## Bounded QM Mechanization

At the first processed D1 bar after a genuine normalized WTI broker-month
transition in year `Y` and month `M`, reconstruct the completed WTI log return
for month `M` in each exact year `Y-5` through `Y-1`. Require all five
observations. Compute the raw odd median and raw median absolute deviation,
freeze the rescaled MAD, execute exactly 32 Hampel re-centering updates, and
trade the final location's sign for one broker month.

The exact sample, single-CFD zero comparison, raw-MAD convention, scale
normalization, median initialization, fixed update count, epsilon, endpoint
normalization, fixed-dollar sizing, ATR hard stop, spread ceiling, attempt
ledger, and lifecycle are transparent QM choices. The sources do not test or
validate those choices.

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

## Exact Hampel Contract

For finite returns `r[0]..r[4]`, ordered from `Y-5` through `Y-1`:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]
scale  = 1.4826 * MAD

mu[0] = median
for j = 0..31:
  u[i] = (r[i] - mu[j]) / scale
  U[i] = abs(u[i])

  w[i] = 1                                  if U[i] <= 2
         2/U[i]                             if 2 < U[i] <= 4
         2*(8-U[i])/(4*U[i])                if 4 < U[i] < 8
         0                                  if U[i] >= 8

  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])

signal = BUY  when mu[32] > +1e-12
         SELL when mu[32] < -1e-12
         FLAT otherwise or when any state is invalid
```

Reject a nonpositive raw MAD, scale, total weight, or nonfinite intermediate.
The scale freezes before the first update. All 32 updates execute. The
boundaries are exact: `U=2` uses weight one, `U=4` uses weight one half, and
`U=8` uses weight zero. There is no convergence stop, return deletion or
replacement, scale refit, alternate start, local-minimum search, fallback
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
  `PORTFOLIO_WEIGHT=1` for non-live pipeline tests.
- Attach one frozen `3.5 * ATR(20,D1)` broker hard stop and no take-profit.
- Reject negative or crossed spreads and genuinely positive spreads above
  1,500 points.
- Lock current news temporal/compliance axes and legacy news mode OFF. Disable
  Friday flattening because the monthly structural hold spans weekends.
- Never scale in, pyramid, grid, martingale, partially close, trail, break
  even, optimize, read a runtime file/API, or consume portfolio state.

## Non-Duplicate Boundary

The corrected canonical receipt
`artifacts/qm5_wti_samecal_hampel5_preallocation_dedup_20260830.json`,
SHA-256
`21A13A996AC51D7DF59C019A5333463D71A6F9FE68CFE7CADB8AD517088E6AD9`,
scanned 4,734 registry identities, 1,372 cards, and 45 Strategy Wiki nodes.
It found no exact identity and only expected same-calendar family neighbors.

For the sorted return fixture
`[-0.050,-0.005,+0.002,+0.005,+0.080]`, the locked Hampel iteration finishes
near `-0.00580512` and sells. The existing five-sample bisquare location
finishes near `+0.000695375` and buys; the raw mean, median, Harrell-Davis,
Gastwirth, trimmed-mean, Winsorized-mean, and trimean locations are positive
and buy. The midhinge is flat. Sign reflection reverses every strict mapping.

`QM5_41204_wti-samecal-huber10` requires ten exact years and retains positive
tail weight. `QM5_41231_wti-samecal-bisquare5` uses a smooth squared compact-
support curve instead of Hampel's unit, plateau-decay, linear-redescending,
and zero regions. The sample map and fixed `2/4/8` boundaries change sides on
the declared fixture; this is not a renamed parameter.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_HAMPEL_248_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1: PASS with disclosed conjunction risk. Two named-author, DOI-bearing,
  peer-reviewed trading papers have complete-read evidence and explicit WTI
  membership. A canonical robust-statistics reference plus author-maintained
  CRAN documentation and source fixes the Hampel convention. The trading
  conjunction is not a published result.
- R2: PASS. Calendar, endpoints, exact years, sample, return orientation,
  median/MAD, scale, constants, boundaries, weights, update count, side,
  attempt, risk, stop, spread, and exits are fixed before testing.
- R3: PASS with warm-up and basis risk. Registered `XTIUSD.DWX` D1 history and
  MT5-native calendar, quote, ATR, symbol, position, deal, and terminal state
  supply every runtime input.
- R4: PASS. Deterministic logarithm, sort, absolute deviation, piecewise
  weight, and fixed arithmetic only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The sources support testing a recurring-calendar own-return WTI carrier, not
the efficacy of this fitted five-observation statistic. Q02 must retire the
card at zero trades, below five completed positions in any full post-warm-up
year, or on nonpositive governed economics. Downstream gates alone own
robustness and realized correlation. No failure may be rescued by changing
the sample, scale, constants, update count, direction, carrier, stop, hold,
spread, or retry contract.

## Safety Boundary

This packet supports one card, deterministic allocation, one non-live V5
build, strict compile/Q01, and one paced target-only Q02 handoff below the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress or
optimization preset, AutoTrading, `T_Live`, deploy manifest, T_Live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or a claim of
profitability or decorrelation.
