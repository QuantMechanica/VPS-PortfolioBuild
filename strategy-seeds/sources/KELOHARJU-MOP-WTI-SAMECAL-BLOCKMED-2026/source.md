---
source_id: KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026
title: WTI same-calendar rolling two-year block-median seasonality extraction
publisher: QuantMechanica governed extraction of peer-reviewed sources
source_type: peer_reviewed_trading_papers_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_same_calendar_block_median_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
  - MOP-WTI-BLOCKMED-2026
parent_sha256:
  - 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  - C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  - 427CEDFC797791818811265DD5054478BCC2BBB7AB8C6D582C550D140D0BE347
created: 2026-08-30
created_by: Research+Development
cards_extracted:
  - wti-samecal-blockmed
---

# WTI Same-Calendar Rolling Two-Year Block-Median Source Packet

## Approval And Source Identity

The durable candidate-specific approval is
`decisions/2026-08-30_wti_same_calendar_block_median_source_approval.md`,
committed as `78362c2f9`. It authorizes one bounded Strategy Card and non-live
build under the current OWNER commodity/energy sleeve mission.

The peer-reviewed trading sources are:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open-paper review is recorded in
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete published-paper
   review is recorded in `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The governed block-aggregation precedent is
`strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md`. All three parent
records were read completely before the source decision. Their hashes are
locked in this packet's front matter and in the approval record.

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
with a symmetric monthly direction. They do not support the exact two-year
block statistic, a single continuous CFD, or any result for this candidate.

## Bounded QM Mechanization

At the first executable D1 tick after a genuine normalized broker-month
transition `(Y,M)`, reconstruct the completed `XTIUSD.DWX` log return for the
same named month `M` in each exact year `Y-5..Y-1`. All five observations are
mandatory. Order them oldest to newest, compute the four overlapping adjacent
two-year arithmetic means, sort only those four rolling means, and average
the two central values. Buy when that even block median is strictly positive,
sell when it is strictly negative, and consume the month flat inside the
locked epsilon band. Renew at the next broker-month boundary.

The exact five-year sample implements the source's eligibility floor and is
testable inside the registered 2017-2025 `XTIUSD.DWX` D1 range. The rolling
block construction asks whether the central smoothed two-year seasonal state
has a stable direction without letting one individual annual shock determine
the signal.

## Exact Statistical Contract

Let `r[0]..r[4]` be the five finite completed same-calendar-month WTI log
returns ordered chronologically from `Y-5` through `Y-1`:

```text
r[k] = ln(month_end_close[Y-5+k,M]
          / prior_month_end_close[Y-5+k,M])

b[0] = (r[0] + r[1]) / 2
b[1] = (r[1] + r[2]) / 2
b[2] = (r[2] + r[3]) / 2
b[3] = (r[3] + r[4]) / 2

s = sort_ascending(b)
location = (s[1] + s[2]) / 2

signal = BUY  when location > +1e-12
         SELL when location < -1e-12
         FLAT otherwise
```

Rolling-pair membership is chronological and immutable. Endpoint returns
appear in exactly the adjacent pairs shown above. Only the four rolling means
are sorted. No individual-return median, full-sample mean, trimming,
winsorization, Hodges-Lehmann pseudomedian, Huber iteration, sign vote,
recency weighting, regime-shift requirement, fallback center, or
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
- Missing years are not substituted. Fewer than all five finite synchronized
  returns consumes the month flat.
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
renewal. The four rolling two-year means, even median, exact five-year
requirement, epsilon,
CFD translation, fixed risk, hard stop, spread ceiling, attempt ledger, and
lifecycle are pre-result QM choices.

No source return, alpha, t-statistic, Sharpe ratio, drawdown, trade count,
cost, WTI-specific result, CFD/futures equivalence, neutrality, decorrelation,
or portfolio statistic transfers. The direct WTI carrier targets exposure
outside the current XAU/SP500/NDX/XNG book, but only unchanged Q09 may measure
realized overlap.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_blockmed_preallocation_dedup_20260830.json`
scanned 4,726 registry identities, 1,364 cards, and 45 Strategy Wiki nodes.
It found no exact identity and one expected fuzzy family match,
`QM5_20099_wti-samecal`, which uses the full-sample arithmetic mean rather
than fixed block means.

The load-bearing executable distinctions are:

- Chronological returns `[-0.10,-0.10,+0.001,+0.10,+0.001]` produce rolling
  means `[-0.10,-0.0495,+0.0505,+0.0505]`. Their even median is `+0.0005`
  while the full-sample mean is `-0.0196`, so this candidate buys while
  `QM5_20099` sells.
- Chronological returns `[-0.10,-0.10,+0.001,+0.001,+0.001]` produce an even
  rolling-mean median of `-0.02425` and an individual-return median of
  `+0.001`, so this candidate sells while `QM5_41055_wti-medcal` buys.
- `QM5_20287_wti-blockmed-mom` groups twelve consecutive recent monthly
  returns into four non-overlapping three-month blocks. This candidate samples
  one named month across five separate years and forms four overlapping
  two-year means. The endpoints, overlap, block width, and economic clocks
  differ.
- Same-calendar trimmed, winsorized, Hodges-Lehmann, Huber, signed-rank,
  t-score, sign-score, recency-weighted, and regime-shift siblings operate on
  individual annual returns or different participation gates; none selects
  the even median of these four rolling two-year means.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FOUR_ROLLING_TWO_YEAR_MEAN_EVEN_MEDIAN_MONTHLY_SLEEVE`.

## Reputable-Source Criteria

- R1:
  `PASS_WITH_BLOCK_AGGREGATION_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact endpoint, block, median, direction, attempt, risk,
  stop, and lifecycle contract.
- R3:
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; deterministic native arithmetic and V5 execution state only.

## Falsification And Safety Boundary

Q02 must retire the candidate on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
wrong or current-month endpoints, missing exact years, incorrect block
membership/divisors/median, wrong side, repeated attempt, missing stop,
invalid fixed-risk mode, wrong lifecycle, or nondeterminism. No failed result
may be rescued by changing the sample, blocks, statistic, direction, carrier,
stop, hold, spread cap, or retry policy.

This packet supports one Strategy Card, deterministic registry allocation,
one branch-only V5 build, strict compile/Q01 validation, and one paced non-live
Q02 handoff only. It does not authorize manual backtesting, live/demo/shadow/
stress/optimization artifacts, AutoTrading, `T_Live`, deploy manifests,
portfolio-gate mutation, portfolio admission, a decorrelation claim, or a
correlation waiver.
