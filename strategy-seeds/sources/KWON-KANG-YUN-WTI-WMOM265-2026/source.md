---
source_id: KWON-KANG-YUN-WTI-WMOM265-2026
title: WTI half-year weekly momentum extraction
publisher: QuantMechanica governed extraction from peer-reviewed research
source_type: peer_reviewed_paper_extraction
status: approved_source_complete
approval_basis: decisions/2026-09-07_wti_halfyear_weekly_momentum_source_approval.md
created: 2026-09-07
created_by: Research+Development
uri: https://doi.org/10.1016/j.frl.2019.101306
cards_extracted:
  - wti-wmom265
---

# WTI Half-Year Weekly Momentum

## Complete-Read Record

Kwon, Kyung Yoon; Kang, Jangkoo; and Yun, Jaesun, *Weekly Momentum
in the Commodity Futures Market*, Finance Research Letters 35 (2020), 101306,
DOI `10.1016/j.frl.2019.101306`.

The retained 20-page accepted manuscript was read completely on 2026-09-07.
Its SHA-256 is
`D768279A0B0F601216FFFA5C48A534939822E7C29B039169ADF0CA817B222F2C`,
matching the governed complete-read records used by the immediately preceding
same-paper cards. The full methodology, adverse results, references, and all
tables were included in the read.

## Source Findings

- The source uses daily settlement prices for 32 US commodity futures from
  January 1979 through June 2015 and rolls to the nearest contract not expiring
  in the next month (pp. 3-4).
- Light sweet crude oil is one of seven energy contracts (Table 1, p. 14).
- In each week `t`, `CMOM26,5` ranks the cumulative return over weeks
  `t-26..t-5`; weeks `t-4..t-1` are excluded and the portfolio is held in week
  `t` (p. 4).
- The source buys the top commodity quintile and sells the bottom quintile.
  It is cross-sectional evidence, not a standalone WTI time-series rule.
- `CMOM26,5` earns 0.14% weekly with t=1.76 in the source sample. Its
  factor-adjusted intercept is 0.06% with t=0.83 and its carry loading is 0.42
  with t=6.19 (Table 2, p. 16).
- With AVG, CARRY, and UMD controls, the intercept is 0.03% with t=0.41 and the
  UMD loading is 0.12 with t=4.82 (Table 3, p. 17).
- The authors conclude that the shorter weekly signal is strongest and that
  longer-horizon momentum is substantially explained by other factors.

## Bounded QM Mechanization

At the first tradable D1 bar of normalized broker week `t`, reconstruct 26
consecutive completed weekly packages. Ignore `t-4..t-1` for signal arithmetic
and compute:

```text
r_halfyear = ln(final_close[t-5] / first_open[t-26])
r_halfyear > 0 => BUY
r_halfyear < 0 => SELL
otherwise      => FLAT
```

The card follows that strict sign for one broker week with one durable attempt,
fixed-dollar risk, and a frozen ATR stop. Two-to-five-session packages admit
holiday-shortened weeks while still rejecting missing, duplicated, unordered,
or six-session packages. No current-week or recent-four-week price enters the
signal.

## Adverse Evidence And Translation Boundary

The source's half-year raw result is not conventionally significant, its alpha
is insignificant, and carry/UMD explain substantial variation. It does not
publish a standalone WTI time-series test, continuous-CFD result, broker-week
label rule, fixed-risk ATR stop, transaction-cost result, or book correlation.
Its futures roll cannot be reproduced by `XTIUSD.DWX`. None of the reported
returns, significance, alpha, causality, neutrality, or decorrelation transfers.

## Non-Duplicate Boundary

The deterministic checker scanned 4,858 registry rows and 1,471 cards. It
found no exact duplicate and three expected same-paper fuzzy siblings; the
external Strategy Wiki root was unavailable and remains an explicit finding.

- `QM5_41375` uses only week `t-1`.
- `QM5_41376` uses only weeks `t-4..t-2` and skips `t-1`.
- `QM5_41377` requires agreement between those two short blocks.
- This identity excludes all of `t-4..t-1` and uses exactly `t-26..t-5`.
- Monthly WTI trend systems use month-end endpoints and monthly lifecycle.

Verdict: `DISTINCT_WTI_CMOM265_EXACT_HALF_YEAR_WEEKLY_BLOCK_CONTINUATION`.

## R1-R4

- R1: `PASS_WITH_WEAK_RAW_AND_FACTOR_SPANNING_EVIDENCE`.
- R2: `PASS`; exact weekly clock, endpoints, exclusion, side, attempt, risk,
  stop, spread, and lifecycle are deterministic.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`.
- R4: `PASS`; native timestamp, OHLC, logarithm, comparison, and ATR only.

## Falsification Boundary

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, inclusion of a
recent-four-week endpoint, broken week chronology, wrong side, repeated
attempts, missing stop, wrong weekly exit, or nondeterminism. No carrier,
horizon, threshold, side, filter, risk, or lifecycle rescue is authorized.
