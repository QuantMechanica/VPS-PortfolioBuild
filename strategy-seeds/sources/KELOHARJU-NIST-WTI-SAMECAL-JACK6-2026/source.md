---
source_id: KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026
title: WTI exact six-year same-calendar delete-one mean sign stability
publisher: QuantMechanica governed composite of peer-reviewed trading sources and NIST statistical documentation
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_same_calendar_jackknife_sign_stability_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-31
created_by: Research
cards_extracted:
  - wti-samecal-jack6
---

# WTI Exact-Six-Year Same-Calendar Jackknife-Stability Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-31_wti_same_calendar_jackknife_sign_stability_source_approval.md`
at commit `2e2bdf203`. It authorizes one card, deterministic allocation, one
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
3. Heckert and Filliben (2003), *NIST Handbook 148: DATAPLOT Reference
   Manual*, Volume II `JACKNIFE INDEX`, complete one-page entry:
   `https://www.itl.nist.gov/div898/software/dataplot/refman2/ch2/jackindx.pdf`.
4. Heckert and Filliben (2003), *NIST Handbook 148: DATAPLOT Reference
   Manual*, Volume I `JACKNIFE ... PLOT`, complete two-page entry:
   `https://www.itl.nist.gov/div898/software/dataplot/refman1/ch2/jacknife.pdf`.

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

Together those findings support falsifying whether WTI returns from the same
named calendar month in exact prior years contain recurring directional
information. Neither paper tests a single-WTI zero comparison, six-year
delete-one sign agreement, or a Darwinex continuous CFD.

## Statistical-Source Findings Used

NIST describes the jackknife as a non-parametric construction that recomputes
a desired statistic after deleting an element, repeats that deletion for each
element, and collects the resulting statistic values. The reference manual
explicitly supports the mean and supplies an index generator that selects the
one omitted element.

This packet uses only that deterministic sample map. It does not estimate a
sampling distribution, confidence interval, bias, standard error, or
pseudovalue. Requiring every delete-one mean to have the same strict sign is
a transparent QM participation gate, not a result or recommendation in the
NIST manual.

## Bounded QM Mechanization

At the first processed D1 bar after a genuine normalized WTI broker-month
transition in year `Y` and month `M`, reconstruct the completed WTI log return
for month `M` in each exact year `Y-6` through `Y-1`. Require all six
observations. Compute all six arithmetic means produced by deleting one
observation at a time. Trade for one broker month only if every recomputed
five-year mean has the same strict sign.

The exact outer sample, single-CFD zero comparison, delete-one unanimity,
epsilon, endpoint normalization, fixed-dollar sizing, ATR hard stop, spread
ceiling, attempt ledger, and lifecycle are transparent QM choices. The
sources do not test or validate those choices.

## Exact Calendar And Endpoint Contract

- Host and traded carrier: exact `XTIUSD.DWX`, D1, symbol slot zero.
- Decision time: the first executable host tick after a normalized broker
  month key changes.
- Target years: exactly `Y-6`, `Y-5`, `Y-4`, `Y-3`, `Y-2`, and `Y-1`; no
  substitute year, shorter sample, or available-history compression.
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

The six returns remain in exact chronological year order from `Y-6` through
`Y-1`. No sorting, winsorization, trimming, replacement, or selected deletion
is allowed.

## Exact Delete-One Sign Contract

For finite chronological returns `r[0]..r[5]`:

```text
for k = 0..5:
  sum_without_k = 0
  for i = 0..5:
    if i != k:
      sum_without_k += r[i]
  loo[k] = sum_without_k / 5

signal = BUY  when loo[k] > +1e-12 for every k=0..5
         SELL when loo[k] < -1e-12 for every k=0..5
         FLAT otherwise or when any state is invalid
```

Require every included return, partial sum, final sum, and mean to be finite.
The divisor is exactly five. The epsilon band is inclusive flat. No full-six
mean, median, standard error, confidence interval, pseudovalue, t-score,
majority vote, magnitude threshold, fallback, or optimization is authorized.

The algorithm does not remove an observation from history. It deterministically
examines all six possible five-observation subsets, and all six must agree.

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
`artifacts/qm5_wti_samecal_jack6_preallocation_dedup_20260831.json`, SHA-256
`4A28903CEB2D62D74D3439D27552E892396CEA3171D55FDE133250946B1D7724`,
scanned 4,735 registry identities, 1,373 cards, and 45 Strategy Wiki nodes.
It found no exact identity and only four expected same-calendar fuzzy
neighbors.

For chronological returns
`[-0.020,-0.010,+0.001,+0.002,+0.003,+0.050]`, the six delete-one means are
`+0.0092`, `+0.0072`, `+0.0050`, `+0.0048`, `+0.0046`, and `-0.0048`, so this
contract remains flat. `QM5_20099` uses only the newest five observations;
their raw mean is `+0.0092` and buys. The last-five median is `+0.002` and
buys. The even median of `QM5_41227`'s four overlapping two-year means is
`+0.002` and buys.

For `[-0.001,+0.002,+0.003,+0.004,+0.005,+0.006]`, all six delete-one means
are positive and this contract buys. Sign reflection sells. The exact sixth
year and unanimity gate therefore control participation and cannot be reduced
to a renamed five-year mean, median, block median, fitted robust location,
score, rank, or recency weight.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_SIX_YEAR_SAME_CALENDAR_DELETE_ONE_FIVE_YEAR_MEAN_UNANIMOUS_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1: PASS with disclosed statistical conjunction and CFD translation risk.
  Two named-author, DOI-bearing, peer-reviewed trading papers have
  complete-read evidence and explicit WTI membership. NIST Handbook 148
  fixes the delete-one mean convention. The unanimous-sign trading gate is
  not a published result.
- R2: PASS. Calendar, endpoints, exact years, return orientation, all six
  subsets, divisor, epsilon, side, attempt, risk, stop, spread, and exits are
  fixed before testing.
- R3: PASS with six-year warm-up and basis risk. Registered `XTIUSD.DWX` D1
  history and MT5-native calendar, quote, ATR, symbol, position, deal, and
  terminal state supply every runtime input.
- R4: PASS. Deterministic logarithm, addition, division, comparisons, and
  fixed arithmetic only; no trained output, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The sources support testing a recurring-calendar own-return WTI carrier and a
reproducible delete-one diagnostic, not the efficacy of this unanimous-sign
gate. Q02 must retire the card at zero trades, below five completed positions
in any full post-warm-up year, or on nonpositive governed economics.
Downstream gates alone own robustness and realized correlation. No failure
may be rescued by changing the outer sample, subset membership, divisor,
epsilon, unanimity, direction, carrier, stop, hold, spread, or retry contract.

## Safety Boundary

This packet supports one card, deterministic allocation, one non-live V5
build, strict compile/Q01, and one paced target-only Q02 handoff below the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress or
optimization preset, AutoTrading, `T_Live`, deploy manifest, T_Live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or a claim of
profitability or decorrelation.
