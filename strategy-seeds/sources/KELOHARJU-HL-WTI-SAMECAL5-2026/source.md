---
source_id: KELOHARJU-HL-WTI-SAMECAL5-2026
title: WTI exact-five-year same-calendar Hodges-Lehmann seasonality extraction
publisher: QuantMechanica governed extraction of Journal of Finance and Journal of Financial Economics sources
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-29_wti_same_calendar_hodges_lehmann5_source_approval.md
parent_source_ids: [KELOHARJU-RETSEAS-2016, MOP-WTI-HLRET-2026]
created: 2026-08-29
created_by: Research+Development
cards_extracted:
  - wti-samecal-hl5
---

# WTI Five-Year Same-Calendar Hodges-Lehmann Source Packet

## Approved Sources Of Record

Two bounded repository packets were read completely before this extraction.

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
   It preserves a complete review of Keloharju, Linnainmaa, and Nyberg
   (2016), "Return Seasonalities," *Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`, including the open 57-page NBER version. Crude
   oil is explicitly one of the 24 commodity futures. The paper forms each
   calendar month's state from returns observed in that same month in prior
   years and requires at least five historical observations.
2. `strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`, SHA-256
   `E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C`.
   It preserves the governed complete-read lineage to Moskowitz, Ooi, and
   Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, explicit WTI membership, and the exact
   inclusive-pair arithmetic used for a Hodges-Lehmann-style return-location
   pseudomedian.

The reproducible complete-read receipt is
`artifacts/qm5_wti_samecal_hl5_source_provenance_20260829.json`.

## Claim Boundary

Keloharju et al. support the recurring same-calendar-month information object,
crude-oil membership, monthly renewal, and five-year eligibility floor. The
second packet supplies governed WTI own-return and inclusive-pair pseudomedian
arithmetic. Neither source tests their exact conjunction, a five-observation
Hodges-Lehmann seasonal estimate, a standalone WTI continuous CFD, the locked
entry and exit plumbing, or the QuantMechanica book.

The exact-five-year sample, inclusive self-pairs, zero comparison, ATR stop,
spread ceiling, fixed cash risk, and one-attempt lifecycle are transparent QM
translations. No source return, alpha, t-statistic, hit rate, density, cost,
drawdown, futures/CFD equivalence, decorrelation, or portfolio result transfers.

## Exact Statistical Contract

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-calendar
month transition in year `Y` and month `M`, reconstruct exactly one completed
log return for month `M` in each year `Y-1` through `Y-5`:

```text
r[y] = ln(last_close(y,M) / last_close(previous_calendar_month(y,M)))
```

Every target endpoint must be the last normalized D1 close in `(y,M)`, the
immediately preceding selected endpoint must be in the immediately preceding
calendar month, and a later D1 bar must prove that the target month completed.
No missing year may be skipped, substituted, or backfilled from another month.

For the five finite chronological returns `r[0]..r[4]`:

```text
k = 0
for i = 0..4:
  for j = i..4:
    w[k] = (r[i] + r[j]) / 2
    k += 1

require k == 15
sorted = ascending copy of w[0..14]
hl = sorted[7]

BUY  when hl > +1e-12
SELL when hl < -1e-12
FLAT otherwise
```

All five self-pairs are mandatory. The current month supplies no price to the
signal, signal magnitude never changes risk, and the raw mean, raw median,
trimmed mean, sign count, signed-rank score, contiguous-return pseudomedian,
trend, fixed-month direction, or external series is never a fallback.

## Locked Execution Translation

- Consume and persist the current broker `yyyymm` before history, signal,
  news, spread, quote, ATR, sizing, margin, or order gates. A rejection,
  failure, stop, restart, or flat signal may not retry in that month.
- Open at most one direct-WTI position under `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Attach one frozen `3.5*ATR(20,D1)` broker hard stop, no target, and reject a
  genuinely positive entry spread above 1,500 points.
- Close on the first processed tick in a later broker month. Thirty-five
  elapsed calendar days is survivor repair only.
- Both news axes, legacy news mode, and framework Friday close are OFF.
- Immediately flatten duplicate, wrong-symbol, wrong-magic, wrong-side,
  invalid-volume, or stopless owned exposure.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,700 registry identities, 1,346 cards, and
all 45 current Strategy Wiki nodes. It found no exact collision and surfaced
only expected same-calendar family neighbors. Receipt:
`artifacts/qm5_wti_samecal_hl5_preallocation_dedup_20260829.json`.

The estimator is functionally distinct:

- `QM5_20099_wti-samecal` takes a raw same-calendar arithmetic mean.
- `QM5_41055_wti-medcal` takes one ordinary raw-return median.
- `QM5_41059_wti-samecal-hit` counts positive observations against a fixed
  hit-rate boundary.
- `QM5_41191_wti-samecal-srank` ranks absolute raw returns and sums signed
  ranks over ten years.
- `QM5_41199_wti-samecal-trim5` sorts the same exact five seasonal returns,
  discards one observation from each tail, and averages the middle three.
- `QM5_20276_wti-hl-mom` applies inclusive pair averages to twelve contiguous
  recent monthly returns rather than five disjoint observations of the
  upcoming calendar month in exact prior years.
- `QM5_41139_wti-mdaily-hl-mom` applies the estimator to daily returns inside
  only the immediately completed month.

For normalized return units `[-11,-9,-8,10,12]`, this rule's 15-value
pseudomedian is `+0.5`, while the raw mean is `-1.2`, raw median is `-8`, and
middle-three trimmed mean is `-7/3`; this rule buys while those functions sell.
For `[-12,-11,5,9,10]`, the pseudomedian is `-1`, while the raw mean is `+0.2`,
raw median is `+5`, and middle-three trimmed mean is `+1`; the disagreement
reverses. The pair expansion, central order statistic, information set, and
direction are therefore load bearing, not naming differences.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_15_WALSH_AVERAGE_HODGES_LEHMANN_SIGN_MONTHLY_RENEWAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: complete
  peer-reviewed *Journal of Finance* same-calendar commodity evidence with
  explicit crude-oil membership, plus complete governed peer-reviewed WTI
  own-return and Hodges-Lehmann-style arithmetic lineage. The exact
  conjunction is explicitly untested.
- R2 `PASS`: label convention, exact years and endpoints, five-return sample,
  fifteen inclusive pairs, divisor, sort, central index, tie band, direction,
  attempt, fixed risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` D1 history and native MT5 state supply every runtime
  field. Five prior exact years are mandatory.
- R4 `PASS`: timestamps, logarithms, pair averages, sorting, comparisons, ATR
  risk controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Q02 retires the unchanged candidate at zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, or
any label, endpoint, exact-year, sample-count, pair-count, self-pair, sort,
central-index, sign, attempt, risk, stop, lifecycle, or determinism defect.
No failure may be rescued by replacing years, changing the estimator, adding a
filter, or altering direction, risk, hold, spread, or retry rules.

Direct WTI supplies crude-oil exposure absent from the stated certified
XAU/SP500/NDX/XNG book, but only unchanged Q09 may establish realized
decorrelation. This packet does not authorize a manual backtest, live/demo/
shadow/stress/optimization setfile, terminal control, AutoTrading, `T_Live`,
deploy or live manifest, portfolio-gate change, portfolio admission, or a
correlation waiver.
