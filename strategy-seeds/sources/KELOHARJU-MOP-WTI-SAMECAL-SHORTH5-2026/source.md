---
source_id: KELOHARJU-MOP-WTI-SAMECAL-SHORTH5-2026
title: WTI exact-five-year same-calendar shortest-half-midmean seasonality extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading sources and official NIST arithmetic
source_type: peer_reviewed_trading_papers_with_official_statistical_reference_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_same_calendar_shorth5_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
  - NIST-DATAPLOT-SHORTEST-HALF-MIDMEAN-2017
parent_sha256:
  - 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  - C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  - WEB_REFERENCE_NO_LOCAL_PAYLOAD
created: 2026-08-30
created_by: Research+Development
cards_extracted:
  - wti-samecal-shorth5
---

# WTI Exact-Five-Year Same-Calendar Shortest-Half-Midmean Source Packet

## Approval And Source Identity

The durable candidate-specific approval is
`decisions/2026-08-30_wti_same_calendar_shorth5_source_approval.md`, committed
as `546b53e9b`. It authorizes one bounded Strategy Card and non-live build
under the current OWNER commodity/energy sleeve mission.

The peer-reviewed trading sources are:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open-paper review is recorded in
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete published-paper
   review is recorded in
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The arithmetic reference is the complete official NIST/SEMATECH Dataplot
"Shortest Half Midmean" page at
`https://www.itl.nist.gov/div898/software/dataplot/refman2/auxillar/shmm.htm`,
read in full on 2026-08-30. NIST describes the estimator as the mean of the
most compact half of an ordered sample, calls out its asymmetric-outlier
resistance, warns that its efficiency is lower than the median, and cites the
robust-location literature. It is an arithmetic provenance, not trading
evidence.

## Trading-Source Findings Used

Keloharju, Linnainmaa, and Nyberg test whether returns recur in the same
named calendar month. Their commodity panel explicitly includes crude oil;
their implementation uses historical same-calendar averages, a minimum of
five years, cross-sectional ranking, and monthly renewal.

Moskowitz, Ooi, and Pedersen identify NYMEX WTI as one of the commodity
futures in their monthly own-return continuation study. Their mechanical
family maps an instrument's past own-return sign into long or short exposure
and renews positions monthly.

Those findings support testing a recurring-calendar WTI information object
with a symmetric monthly direction. They do not support the shortest-half
midmean, an exact five-year single-instrument estimator, a continuous CFD, or
any performance result for this candidate.

## Bounded QM Mechanization

At the first executable D1 tick after a genuine normalized broker-month
transition `(Y,M)`, reconstruct the completed `XTIUSD.DWX` log return for the
same named month `M` in each exact year `Y-5..Y-1`. All five observations are
mandatory. Sort them ascending, compare the spans of the three adjacent
three-value windows, retain the earliest window having the strictly smallest
span, and average its three values. Buy when that location is strictly
positive, sell when it is strictly negative, and consume the month flat
inside the locked epsilon band. Renew at the next broker-month boundary.

The exact five-year sample implements the source's eligibility floor and is
testable inside the registered 2017-2025 `XTIUSD.DWX` D1 range. The
shortest-half location asks whether the densest three of five annual seasonal
observations have a directional center without letting two remote annual
observations determine the signal. This is a pre-result robustness hypothesis,
not a claim that outlying returns are errors or that the selected cluster is
the true regime.

## Exact Statistical Contract

Let `r[0]..r[4]` be the five finite completed same-calendar-month WTI log
returns from exact years `Y-5` through `Y-1`. Sort them into
`x[0] <= x[1] <= x[2] <= x[3] <= x[4]`:

```text
span[0] = x[2] - x[0]
span[1] = x[3] - x[1]
span[2] = x[4] - x[2]

k = 0
if span[1] < span[k]: k = 1
if span[2] < span[k]: k = 2

location = (x[k] + x[k+1] + x[k+2]) / 3

signal = BUY  when location > +1e-12
         SELL when location < -1e-12
         FLAT otherwise
```

Only a strictly smaller later span may replace the current winner, so exact
ties select the lowest starting index. The implementation must sort exactly
five individual returns once, compute exactly three full endpoint spans, and
divide exactly the selected three-value sum by three. No range midpoint,
multiple-window average, chronological block, full-sample mean, ordinary
median, symmetric trim, winsorization, Hodges-Lehmann pseudomedian, Huber
iteration, sign vote, recency weighting, regime filter, fallback center, or
signal-magnitude sizing is permitted.

## Endpoint And Clock Contract

- Exact host and traded symbol: `XTIUSD.DWX`, D1, magic slot 0.
- Accept only one uniform native or `+1` energy D1-label convention. The
  normalized current host D1 date must equal the broker date and the same
  offset applies to every historical endpoint.
- Each return uses the final completed close of the immediately prior month
  and the final completed close of the named month. A later confirming D1 bar
  must exist. Current-month price, volume, quote, or partial bar may not enter
  the signal.
- Missing years are not substituted. Fewer than all five finite returns
  consumes the month flat.
- Persist broker `yyyymm` before history, signal, news, spread, quote, ATR,
  sizing, or submission. No rejected or stopped attempt retries that month.
- Close the old package before computing a replacement at the next genuine
  normalized broker-month boundary. Forty elapsed calendar days is a final
  survivor repair only.

## Risk And Execution Contract

- Backtest baseline only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One frozen broker hard stop at `3.5 * ATR(20,D1)` from completed data and no
  take-profit.
- Entry spread must be finite and nonnegative and may not exceed 1,500 WTI
  points. Quotes, stop geometry, tick value, tick size, and volume metadata
  must be valid.
- Both current news axes and legacy news mode are OFF. Framework Friday close
  is OFF because the source-aligned monthly hold spans weekends.
- Lifecycle repair immediately closes duplicate, wrong-symbol, invalid-side,
  wrong-magic, or stopless owned exposure before any entry-only gate.
- No intramonth signal flip, target, trail, break-even, partial close,
  scale-in, grid, martingale, pyramid, optimizer output, trained signal,
  external file, API, futures curve, inventory, volume, open interest, or
  event feed is allowed.

## Claim Boundary

The trading sources support only recurring same-calendar commodity
information, explicit WTI membership, own-return direction, and monthly
renewal. NIST supports only the public arithmetic definition and cautions
about efficiency. The exact five-year shortest-three implementation,
earliest-window tie break, epsilon, CFD translation, fixed risk, hard stop,
spread ceiling, attempt ledger, and lifecycle are pre-result QM choices.

No source return, alpha, t-statistic, Sharpe ratio, drawdown, trade count,
cost, WTI-specific result, CFD/futures equivalence, neutrality, decorrelation,
or portfolio statistic transfers. The direct WTI carrier targets exposure
outside the current XAU/SP500/NDX/XNG book, but only unchanged Q09 may measure
realized overlap.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_shorth5_preallocation_dedup_20260830.json`
scanned 4,727 registry identities, 1,365 cards, and 45 Strategy Wiki nodes.
It found no exact identity and one expected fuzzy family match,
`QM5_20099_wti-samecal`, which uses a full-sample arithmetic mean rather than
a shortest-three location.

The load-bearing executable distinctions are:

- Sorted returns `[-0.20,-0.19,+0.001,+0.20,+0.21]` produce spans
  `[0.201,0.390,0.209]` and location `-0.1296666667`, so this candidate sells.
  The full mean is `+0.0042`, the individual median is `+0.001`, the middle
  three-value trimmed mean is `+0.0036666667`, and the endpoint-Winsorized mean
  is `+0.0042`; those neighboring location families buy.
- Exact-binary returns
  `[-0.03125,-0.015625,0,+0.015625,+0.03125]` give three equal spans. The
  earliest-window tie rule selects the first triplet and location
  `-0.015625`, while the raw mean and ordinary median are flat.
- `QM5_41227_wti-samecal-blockmed` retains chronological order and takes the
  even median of four overlapping two-year means. This candidate sorts away
  year order and selects one compact three-value return-space interval.
- Same-calendar trimmed, winsorized, Hodges-Lehmann, Huber, signed-rank,
  t-score, sign-score, median, recency-weighted, and regime-shift siblings do
  not use data-dependent shortest-interval membership and the earliest-index
  tie rule.
- Contiguous-month and within-month robust WTI systems observe a different
  economic clock and sample object; they are not parameter variants of one
  named month across exact separate years.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_SHORTEST_THREE_MIDMEAN_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1:
  `PASS_WITH_SHORTEST_HALF_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact endpoint, sort, span, tie, location, direction,
  attempt, risk, stop, and lifecycle contract.
- R3:
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; deterministic native arithmetic and V5 execution state only.

## Falsification And Safety Boundary

Q02 must retire the candidate on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
wrong or current-month endpoints, missing exact years, incorrect sort/window/
span/tie/divisor, wrong side, repeated attempt, missing stop, invalid fixed-risk
mode, wrong lifecycle, or nondeterminism. No failed result may be rescued by
changing the sample, window size, statistic, direction, carrier, stop, hold,
spread cap, or retry policy.

This packet supports one Strategy Card, deterministic registry allocation,
one branch-only V5 build, strict compile/Q01 validation, and one paced non-live
Q02 handoff only. It does not authorize manual backtesting, live/demo/shadow/
stress/optimization artifacts, AutoTrading, `T_Live`, deploy manifests,
portfolio-gate mutation, portfolio admission, a decorrelation claim, or a
correlation waiver.
