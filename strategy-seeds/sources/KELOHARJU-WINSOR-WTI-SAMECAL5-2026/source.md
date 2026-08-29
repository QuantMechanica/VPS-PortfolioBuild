---
source_id: KELOHARJU-WINSOR-WTI-SAMECAL5-2026
title: WTI exact-five-year same-calendar one-tail Winsorized seasonality extraction
publisher: QuantMechanica governed extraction of Journal of Finance and Journal of Financial Economics sources
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-29_wti_same_calendar_winsorized5_source_approval.md
parent_source_ids: [KELOHARJU-RETSEAS-2016, MOP-WTI-WINSOR-2026]
created: 2026-08-29
created_by: Research+Development
cards_extracted:
  - wti-samecal-win5
---

# WTI Five-Year Same-Calendar Winsorized Source Packet

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
2. `strategy-seeds/sources/MOP-WTI-WINSOR-2026/source.md`, SHA-256
   `9995A84CC81057042EE480ED95BD9816FBA9FE2304DAC4A6FC89B4F19E194EEF`.
   It preserves the governed complete-read lineage to Moskowitz, Ooi, and
   Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, explicit WTI
   membership, and exact fixed-tail Winsorization arithmetic on monthly WTI
   own returns.

The reproducible complete-read receipt is
`artifacts/qm5_wti_samecal_win5_source_provenance_20260829.json`.

## Claim Boundary

Keloharju et al. support the recurring same-calendar-month information object,
crude-oil membership, monthly renewal, and five-year eligibility floor. The
second packet supplies governed WTI own-return and fixed-tail Winsorization
arithmetic. Neither source tests their exact conjunction, one-per-tail
Winsorization of five observations, a standalone WTI continuous CFD, the
locked entry and exit plumbing, or the QuantMechanica book.

The exact-five-year sample, one replacement per tail, zero comparison, ATR
stop, spread ceiling, fixed cash risk, and one-attempt lifecycle are
transparent QM translations. No source return, alpha, t-statistic, hit rate,
density, cost, drawdown, futures/CFD equivalence, decorrelation, or portfolio
result transfers.

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

For the five finite returns, sort an independent copy ascending:

```text
s[0] <= s[1] <= s[2] <= s[3] <= s[4]
w = [s[1], s[1], s[2], s[3], s[3]]
winsor_mean = sum(w[0..4]) / 5
             = (2*s[1] + s[2] + 2*s[3]) / 5

BUY  when winsor_mean > +1e-12
SELL when winsor_mean < -1e-12
FLAT otherwise
```

Both original extremes remain represented only through their nearest retained
boundaries. This is capping, not deletion: the statistic always has five
terms, while `s[1]` and `s[3]` each receive weight two. The current month
supplies no price to the signal, signal magnitude never changes risk, and the
raw mean, raw median, middle-three trimmed mean, inclusive-pair pseudomedian,
sign count, signed-rank score, contiguous-return Winsorized mean, trend,
fixed-month direction, or external series is never a fallback.

## Locked Execution Translation

- Consume and persist current broker `yyyymm` before history, signal, news,
  spread, quote, ATR, sizing, margin, or order gates. Rejection, failure, stop,
  restart, or flat signal may not retry in that month.
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

The fail-closed checker scanned 4,701 registry identities, 1,347 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and surfaced only
expected same-calendar family neighbors. Receipt:
`artifacts/qm5_wti_samecal_win5_preallocation_dedup_20260829.json`.

The estimator is functionally distinct:

- `QM5_20099_wti-samecal` takes a raw same-calendar arithmetic mean.
- `QM5_41055_wti-medcal` takes one raw-return median.
- `QM5_41059_wti-samecal-hit` counts positive observations against a fixed
  hit-rate boundary.
- `QM5_41191_wti-samecal-srank` ranks absolute returns over up to ten years.
- `QM5_41199_wti-samecal-trim5` deletes the same sample's minimum and maximum
  and divides only the middle-three sum by three.
- `QM5_41201_wti-samecal-hl5` forms fifteen inclusive pair averages and
  selects their central order statistic.
- `QM5_20277_wti-winsor-mom` Winsorizes two observations per tail among twelve
  contiguous recent monthly returns. It does not use five disjoint exact-year
  observations of the upcoming calendar month.

For normalized return units `[-12,-11,3,9,10]`, this five-term Winsorized mean
is `-0.2`, while the middle-three trimmed mean is `+1/3`, the raw median is
`+3`, and three of five observations are positive. For
`[-12,-9,3,8,9]`, it is `+0.2`, while the raw mean is `-0.2` and the
fifteen-pair central value is `-0.5`. The replacement indexes, retained
weights, divisor, information set, and direction are load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_ONE_TAIL_WINSORIZED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: complete
  peer-reviewed *Journal of Finance* same-calendar commodity evidence with
  explicit crude-oil membership, plus complete governed peer-reviewed WTI
  own-return and Winsorization lineage. The exact conjunction is untested.
- R2 `PASS`: label convention, exact years and endpoints, five-return sample,
  sort, replacement indexes, retained weights, divisor, tie band, direction,
  attempt, fixed risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` D1 history and native MT5 state supply every input.
- R4 `PASS`: timestamps, logarithms, sorting, fixed replacement, comparisons,
  ATR risk controls, and execution state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Q02 retires the unchanged rule at zero trades, below five completed packages
in any full post-warm-up year, nonpositive governed economics, or any
endpoint, exact-year, sort, replacement, weight, divisor, sign, attempt, risk,
stop, lifecycle, or determinism defect. No failed result may be rescued by
changing years, tail count, estimator, direction, carrier, stop, hold, spread,
or retry rules.

This packet authorizes card extraction only under its durable decision. It does
not authorize a manual backtest, live artifact, `T_Live`, AutoTrading, deploy
manifest, portfolio-gate change, portfolio admission, correlation waiver, or
claim that the sleeve is already uncorrelated.
