---
source_id: KWON-KANG-YUN-WTI-WMOM142-AGREE-2026
title: WTI disjoint weekly momentum agreement extraction
publisher: QuantMechanica governed extraction from peer-reviewed research
source_type: peer_reviewed_paper_composite_extraction
status: approved_source_complete
approval_basis: decisions/2026-09-07_wti_disjoint_weekly_momentum_agreement_source_approval.md
created: 2026-09-07
created_by: Research+Development
uri: https://doi.org/10.1016/j.frl.2019.101306
cards_extracted:
  - wti-wmom142-agree
---

# WTI Disjoint Weekly Momentum Agreement

## Complete-Read Record

Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun, *Weekly Momentum
in the Commodity Futures Market*, Finance Research Letters 35 (2020), 101306,
DOI `10.1016/j.frl.2019.101306`.

The governed parent records at
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md` and
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/source.md` preserve the
complete 20-page accepted-manuscript read, University of Strathclyde retrieval
URL, and PDF SHA-256
`D768279A0B0F601216FFFA5C48A534939822E7C29B039169ADF0CA817B222F2C`.
This bounded child uses no source claim outside those complete-read records.

A fresh 2026-09-07 router attempt on the DOI and accepted-manuscript URL was
classified `DEFERRED:SOURCE_POLICY`; the exact receipt is
`artifacts/wti_wmom142_source_router_receipt_20260907.json`. No alternate
retrieval route or bypass was attempted.

## Source Findings

- The source studies daily settlement prices for 32 US commodity futures from
  January 1979 through June 2015 and explicitly includes light sweet crude oil.
- `CMOM1,1` uses the immediately preceding week `t-1` and holds the ranked
  commodity portfolio during week `t`.
- `CMOM4,2` uses cumulative return over weeks `t-4` through `t-2`, excludes
  `t-1`, and holds the ranked commodity portfolio during week `t`.
- The two formation intervals are disjoint and known before week `t` begins.
- The paper reports that `CMOM4,2` is largely captured by `CMOM1,1`; its
  regression intercept becomes insignificant. This adverse dependence is
  retained, not hidden.
- The source portfolios are cross-sectional winner-minus-loser portfolios.
  They are not standalone WTI time-series rules.

## QM Composite Hypothesis

The source does not test a conjunctive `CMOM1,1`/`CMOM4,2` rule. QM therefore
treats sign agreement between the disjoint blocks as a new falsifiable
hypothesis, not a source result. At the first tradable D1 bar of broker week
`t`, reconstruct four consecutive completed three-to-five-session weeks.
Compute:

```text
r_recent = ln(final_close[t-1] / first_open[t-1])
r_prior  = ln(final_close[t-2] / first_open[t-4])
```

Buy only when both are strictly positive; sell only when both are strictly
negative; stay flat for disagreement, equality, invalid arithmetic, or broken
week chronology. Consume the week before fallible gates, use one fixed-risk
position with a frozen `3.5*ATR(20,D1)` stop, and flatten at the next broker-
week boundary.

This construction adds no magnitude, volatility, range, calendar-month,
weekday-direction, moving-average, oscillator, volume, inventory, curve,
external-data, or portfolio-state filter.

## Adverse Evidence And Translation Boundary

No source performance, statistical significance, causality, independence,
transaction-cost result, WTI-only result, continuous-CFD equivalence, or book
decorrelation transfers. Requiring agreement may merely lower density without
improving economics because the source itself reports spanning. The source's
futures roll rule also cannot be reproduced by `XTIUSD.DWX`. Q02 must falsify
density and economics; Q09 alone may measure realized correlation.

## Non-Duplicate Boundary

The canonical checker scanned 4,857 EA-registry rows and 1,470 cards. It found
only the expected fuzzy parents `QM5_41375_wti-wmom1` and
`QM5_41376_wti-wmom42`; the external Strategy Wiki root was unavailable and
remains an explicit receipt finding.

- `QM5_41375` trades every valid nonzero `t-1` sign and never reads the
  `t-4..t-2` state.
- `QM5_41376` trades every valid nonzero `t-4..t-2` sign and deliberately
  excludes `t-1` from its signal.
- `QM5_41022_wti-wdual-mom` requires agreement between two disjoint segments
  inside one completed calendar week and exits through Friday close. This
  card compares two source-defined multi-week blocks and exits at the next
  normalized week boundary.
- Adjacent-week acceleration, deceleration, flip, pullback, and path-pattern
  systems compare individual completed-week returns or magnitudes. This card
  has no adjacent-return pattern or magnitude condition.
- Monthly dual-horizon systems use month-end closes and monthly lifecycle.

The load-bearing identity is strict agreement between exactly the independent
`t-1` and cumulative `t-4..t-2` source states. Removing either state recreates
one parent. Verdict:
`DISTINCT_WTI_CMOM11_CMOM42_DISJOINT_SIGN_AGREEMENT_WEEKLY_CONTINUATION`.

## R1-R4

- R1: `PASS_WITH_COMPOSITE_AND_TIME_SERIES_PORT_RISK`; one complete reputable
  peer-reviewed source defines both disjoint horizons and WTI membership;
  adverse spanning evidence and the untested conjunction are explicit.
- R2: `PASS`; clock, endpoints, agreement, side, attempt, risk, stop, spread,
  and lifecycle are fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4: `PASS`; deterministic timestamp, OHLC, logarithm, comparison, ATR, and
  framework-state arithmetic without ML or banned signals.

## Falsification Boundary

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, disagreement-state
entry, mixed energy labels, nonconsecutive weeks, endpoint leakage, repeated
attempts, missing stop, wrong week exit, or nondeterminism. No carrier, block,
threshold, side, filter, risk, or lifecycle rescue is authorized.
