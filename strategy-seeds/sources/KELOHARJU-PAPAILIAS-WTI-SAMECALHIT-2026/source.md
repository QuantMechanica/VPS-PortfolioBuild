---
source_id: KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026
title: WTI same-calendar-month positive-return hit-rate seasonality
publisher: The Journal of Finance / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-18
created: 2026-08-18
created_by: Research+Development
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - PAPAILIAS-RSM-2021
strategy_ids:
  - KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01
---

# WTI Same-Calendar Hit-Rate Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-18 directs one new structural, low-frequency
commodity/energy card, branch-only non-live build, and paced Q02 enqueue. This
packet joins two governed, completely reviewed, peer-reviewed source lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete 57-page NBER version was reviewed
   under `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
   "Return Signal Momentum," *Journal of Banking & Finance* 124, 106063,
   DOI `10.1016/j.jbankfin.2021.106063`. The accepted manuscript, including
   appendices and individual-instrument tables, was reviewed under
   `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`.

Both bounded parent records were read completely for this extraction. No web
summary substitutes for them, and the runtime reads no external source.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg rank commodities using historical returns
  in the same calendar month. Their 24-future commodity universe explicitly
  includes crude oil, and their estimator requires at least five years of
  matching-month history.
- Papailias, Liu, and Thomakos explicitly include WTI and define a return-sign
  representation: a completed return is `1` when non-negative and `0` when
  negative, and the equal-weight average of those binary observations is an
  estimated positive-return probability.
- Keloharju et al. use return magnitudes and a broad cross-section; Papailias
  et al. apply sign frequency to twelve consecutive recent monthly returns.
  Neither paper applies binary signs to prior occurrences of one calendar
  month, trades a single Darwinex WTI CFD, or specifies the V5 lifecycle. The
  conjunction is a predeclared QM falsification hypothesis.

No source return, alpha, t-statistic, hit rate, trade density, profit factor,
drawdown, CFD-equivalence, or portfolio-correlation result transfers.

## Bounded Mechanization

`KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01` locks one monthly WTI package:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- decision: first executable D1 tick of each genuine normalized broker month;
- history: up to ten prior occurrences of the decision calendar month,
  requiring at least five valid completed log returns;
- observation: `v_y = 1` when a prior same-calendar return is non-negative and
  `v_y = 0` when it is negative, matching the governed Papailias sign map;
- state: `positive_frequency = sum(v_y) / n`, with equal weight and no return
  magnitude, recency weight, fitted coefficient, or interpolation;
- direction: BUY when `positive_frequency >= 0.40` and SELL otherwise;
- lifecycle: close and renew at the next normalized month boundary;
- frozen `3.5 * ATR(20,D1)` hard stop, no target, 35-calendar-day stale guard,
  1,500-point spread ceiling, and one durable attempt per broker month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The fixed `0.40` decision boundary is Papailias et al.'s source-defined
threshold, transferred without a QM data sweep from consecutive recent-month
signs to the matching-calendar-month sign sample. That conjunction is the
disclosed translation risk. Q02 has no optimization surface.

## Non-Duplicate Boundary

The canonical pre-card command scanned 4,546 EA-registry rows and 625 cards
and returned `CLEAN`, with no exact or fuzzy hit for slug `wti-samecal-hit`,
strategy ID `KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01`, or the full
mechanic. Manual semantic review fixes the nearest boundaries:

- `QM5_20099_wti-samecal` takes the sign of an arithmetic mean of historical
  same-month return magnitudes. One extreme observation can change its side;
  this candidate discards every magnitude and counts equal binary signs.
- `QM5_41055_wti-medcal` takes the sign of the sample median return. With five
  observations, two small gains and three larger losses, this candidate is
  long at the source-defined `0.40` boundary while the median is negative.
- `QM5_20251_wti-cal-rsm` requires agreement between a same-calendar
  arithmetic mean and a separate recent twelve-month sign-momentum state.
  This candidate has one historical matching-month sign-frequency state and
  no recent-return confirmation.
- `QM5_20136_wti-caltrend` and `QM5_20205_wti-calmom1` combine the
  same-calendar mean with contiguous trend or the immediately completed
  month. This candidate has neither input.
- `QM5_13150_wti-signmom` uses the same `0.40` threshold across the twelve
  immediately preceding months. This candidate samples the same named month
  across prior years instead of contiguous recent history.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  rather than symmetric monthly WTI seasonality.

Verdict:
`CLEAN_WTI_SAME_CALENDAR_POSITIVE_RETURN_FREQUENCY_AFTER_FAMILY_REVIEW`.

The matching-month sample, binary sign map, equal weighting, fixed `0.40`
boundary, single WTI carrier, monthly decision clock, and monthly lifecycle
are jointly load-bearing. Changing any one creates a different identity.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two named-author peer-reviewed
  finance papers with DOI, durable complete-read records, explicit crude-oil
  membership, and a disclosed untested conjunction.
- R2 `PASS`: exact same-calendar endpoints, five-to-ten sample bounds, binary
  map, equal-weight hit rate, fixed `0.40` direction, durable attempt,
  fixed stop, spread guard, and monthly exit are deterministic and locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XTIUSD.DWX` D1 history and
  native MT5 state supply every runtime input; the continuous-CFD/futures
  basis remains for Q02 to falsify.
- R4 `PASS`: native timestamp, calendar, OHLC, logarithm, binary arithmetic,
  ATR risk plumbing, quote, position, deal, and terminal state only; no ML,
  banned signal, external feed, optimizer artifact, grid, martingale,
  scale-in, or pyramid.

## Kill And Safety Boundary

Expected cadence is twelve completed monthly positions per full post-warm-up
year when history is valid; invalid-history months remain flat. Q02 must
retire on zero trades, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, wrong historical
month endpoints, current-month leakage, wrong sign count or boundary, late or
repeated entry, wrong monthly lifecycle, nondeterminism, invalid fixed-risk
mode, or insufficient local history. A weak result may not be rescued by
changing the threshold, lookback, estimator, stop, hold, or carrier.

This source packet authorizes no manual backtest, terminal control, live/demo/
shadow/stress/optimization preset, AutoTrading action, `T_Live` change,
deploy or T_Live manifest, portfolio-gate mutation, portfolio admission,
decorrelation claim, or correlation waiver.
