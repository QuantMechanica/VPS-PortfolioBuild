---
source_id: KELOHARJU-PAPAILIAS-WTI-CALRSM-2026
title: WTI same-calendar seasonality and return-sign-momentum concordance
publisher: The Journal of Finance / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-06
created: 2026-08-06
created_by: Research+Development
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - PAPAILIAS-RSM-2021
strategy_ids:
  - KELOHARJU-PAPAILIAS-WTI-CALRSM-2026_S01
---

# WTI Same-Calendar / Return-Sign Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-06 directs one new structural, low-frequency
commodity/energy card, branch-only build, and paced Q02 enqueue. This packet
joins two already governed, completely reviewed, peer-reviewed source
lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete 57-page NBER version was reviewed
   under `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
   "Return Signal Momentum," *Journal of Banking & Finance* 124, 106063,
   DOI `10.1016/j.jbankfin.2021.106063`. The accepted manuscript, including
   appendices and instrument tables, was reviewed under
   `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`.

Both bounded parent packets were read completely for this extraction. No
fresh web text substitutes for them, and the EA reads no external source at
runtime. The durable G0 boundary is
`decisions/2026-08-06_qm5_20251_wti_cal_rsm_g0.md`.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg rank commodities by their average return
  in the same calendar month over prior years. Their 24-future commodity
  universe explicitly includes crude oil, and the governed WTI translation
  requires at least five prior matching-month observations.
- Papailias, Liu, and Thomakos explicitly include WTI. Their fixed return-sign
  state converts the prior twelve completed monthly returns to `1` when
  non-negative and `0` when negative, averages those signs, classifies long
  at probability `>= 0.40` and short otherwise, and renews monthly.
- Neither paper tests the agreement of those two WTI states, a Darwinex
  continuous CFD, fixed cash risk, an ATR hard stop, or the QM portfolio.
  The conjunction is a predeclared QM falsification hypothesis.

No source return, Sharpe, profit factor, drawdown, hit rate, trade count,
CFD-basis result, or portfolio-correlation statistic is imported. The adverse
WTI drawdown evidence recorded in the Papailias packet remains part of the
risk boundary.

## Bounded Mechanization

`KELOHARJU-PAPAILIAS-WTI-CALRSM-2026_S01` locks one monthly WTI package:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of every genuine broker-calendar month;
- seasonal state: arithmetic mean of WTI's completed log return for the
  decision calendar month over up to ten prior years, requiring at least five
  valid observations;
- return-sign state: thirteen consecutive completed broker-month endpoints
  form twelve returns; non-negative returns count as `1`, negative returns as
  `0`, and `positive_probability = count / 12`;
- return-sign direction: long when `positive_probability >= 0.40`, short
  otherwise;
- buy only when the same-calendar mean is strictly positive and the
  return-sign direction is long;
- sell only when the same-calendar mean is strictly negative and the
  return-sign direction is short;
- disagreement, an exact-zero seasonal mean, insufficient/nonconsecutive
  history, or invalid arithmetic consumes the month flat;
- close and, when agreement exists, renew at the next month boundary;
- frozen `3.5 * ATR(20,D1)` hard stop, 40-calendar-day stale guard,
  1,500-point spread ceiling, and one persisted attempt per broker month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The two always-directed states should agree on roughly half to three quarters
of valid monthly decisions under a weak prior, giving an ex-ante estimate of
six to nine completed packages per full post-warm-up year. Q02 must measure
the actual density and retire the carrier below five. No threshold or fallback
may be fitted after results.

## Non-Duplicate Boundary

The pre-allocation deterministic command scanned 4,308 EA-registry rows and
425 direct research cards. It returned `CLEAN`, with no exact or fuzzy hit for
slug `wti-cal-rsm`, strategy ID
`KELOHARJU-PAPAILIAS-WTI-CALRSM-2026_S01`, or the complete mechanic.

Manual semantic review resolves the nearest registered systems:

- `QM5_20099_wti-samecal` follows the historical same-calendar sign alone;
- `QM5_13150_wti-signmom` follows the twelve-return sign state alone;
- `QM5_20136_wti-caltrend` confirms same-calendar seasonality with one
  completed 63-D1 cumulative return, not twelve binary monthly signs;
- `QM5_20205_wti-calmom1` confirms same-calendar seasonality with exactly the
  immediately completed calendar-month return, not sign breadth;
- `QM5_20222_wti-seas-sign` uses a hard-coded November-May / June-October
  physical-season direction rather than an adaptive same-calendar estimator;
- `QM5_20244_wti-trend-sign` agrees a 12-month cumulative return with the
  sign state and contains no recurring calendar-month history; and
- `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator pullback.

The prior-year matching-month sample, absolute seasonal sign, twelve binary
monthly signs, fixed `0.40` threshold, strict agreement, disagreement-flat
state, and monthly lifecycle are jointly load-bearing. Removing either state
recreates a built parent; changing the seasonal estimator, threshold,
direction, lookback, carrier, or agreement rule creates a new strategy.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed finance papers with DOI, durable
  complete-read repository packets, and explicit crude-oil/WTI membership.
- R2: PASS. Month endpoints, ten-year bounded same-calendar estimator,
  five-sample floor, twelve binary signs, fixed threshold, agreement mapping,
  attempt state, stop, spread, and exits are deterministic and locked.
- R3: PASS. Registered `XTIUSD.DWX` D1 data supplies every runtime input; no
  futures curve or external series is required.
- R4: PASS. Native OHLC, ATR, calendar, quote, deal, position, and framework
  state only; no trained model, banned indicator, external feed, grid,
  martingale, scale-in, pyramiding, or adaptive PnL rule.

## Claim And Safety Boundary

The source papers use diversified rolling futures portfolios. Continuous-CFD
roll construction, financing, gaps, limited same-month samples, source decay,
one-name breadth, interaction sparsity, and WTI/XNG portfolio overlap are
binding Q02 and later-gate risks. Only the unchanged Q09 portfolio gate may
establish realized decorrelation.

This approval covers one Strategy Card, deterministic allocation, V5 build,
strict compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue.
It excludes manual backtests; live, demo, shadow, optimization, or stress
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers.
