---
source_id: FAN-MICROMOM-2014
title: Momentum Investing in Commodity Futures - Chapter 3, Microscopic Momentum
publisher: Griffith University
source_type: doctoral_thesis_chapter
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://research-repository.griffith.edu.au/server/api/core/bitstreams/5b940466-77cf-5789-bdf3-14987ca5a12a/content
cards_extracted:
  - energy-micro11
---

# Fan Microscopic-Momentum Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity or energy card, build, and Q02 enqueue.
- The bounded approved source is Chapter 3, Microscopic Momentum, pages 62-106
  of John Hua Fan's Griffith University doctoral thesis. The chapter was read
  end to end, including literature, data, roll construction, portfolio method,
  results, robustness, transaction costs, factor tests, and conclusion.
- The later Bianchi-Drew-Fan working-paper record and abstract were reviewed as
  a supplement. They restate the 11-to-10-month construction and its separation
  from conventional commodity momentum.
- This packet extracts only the source's Mom11,10 rule. It does not extract the
  other microscopic months, conventional momentum, echo momentum, or the
  separate momentum/reversal and 52-week-high thesis chapters.

## Primary Citation

Fan, John Hua (2014), Momentum Investing in Commodity Futures, PhD thesis,
Griffith University, Chapter 3, Microscopic Momentum, pp. 62-106.

Institutional full text:
https://research-repository.griffith.edu.au/server/api/core/bitstreams/5b940466-77cf-5789-bdf3-14987ca5a12a/content

Related working-paper record:
https://ssrn.com/abstract=2827237

## Relevant Source Locations

- Pages 62-64: the 11,10 microscopic strategy is identified as a single-month
  return signal with return dynamics distinct from conventional momentum.
- Pages 67-71: the source universe includes WTI crude oil and natural gas; it
  uses continuous commodity excess-return series, monthly endpoints, tercile
  ranks, winner-minus-loser portfolios, and one-month holds.
- Page 70 and Figure 3-1: Mom(T+1,T) uses the return between T+1 and T months
  before formation; all microscopic portfolios buy winners, short losers, and
  hold one month without a skipped month.
- Pages 81-84 and Table 3-4: Mom11,10 is the only microscopic month with a
  statistically significant full-sample winner-minus-loser result and has low
  correlation with conventional 12-month momentum.
- Pages 87-93: sub-period, independent-data, sector-exclusion,
  calendar-exclusion, breakpoint, alternate-endpoint, and cost checks.
- Pages 94-106: the 11,10 component subsumes intermediate echo momentum but
  does not fully explain conventional momentum; factor tests and limitations
  are preserved.

## Bounded Mechanization

At the first tradable XTIUSD.DWX D1 bar of broker month t, obtain synchronized
completed D1 closes immediately before the month boundaries t-11 and t-10.
For each energy leg i:

    micro11_i = log(close_i_before_boundary_t_minus_10 /
                    close_i_before_boundary_t_minus_11)

Buy the higher-micro11 energy leg and short the lower leg. Hold the paired
package until the next broker-month transition, with a 35-day stale guard,
equal fixed-risk halves, frozen ATR hard stops, restart-safe month guards, and
orphan cleanup.

This keeps the source's isolated one-month formation slice, cross-sectional
winner-minus-loser direction, monthly formation, and one-month hold. It narrows
27 futures and tercile portfolios to two continuous broker CFDs. It therefore
does not claim to replicate the source or inherit any source performance.

## Evidence Boundary

- The source's exact Mom11,10 result is institutional doctoral research and a
  later complete academic working paper, not a peer-reviewed journal article.
  This is a source-quality limitation retained for Q02, not concealed by the
  related authors' peer-reviewed commodity-momentum publications.
- The source uses diversified S&P GSCI excess-return series with embedded roll
  yield. Darwinex continuous CFDs can have different rolls, financing, and
  contract stitching.
- Two energy legs cannot reproduce source terciles, diversification, or equal
  contract portfolios. An XTI/XNG rank always chooses an extreme even when the
  two signals are economically close.
- Source robustness after excluding the energy sector does not prove an
  energy-only carrier. Q02 must establish density and economics independently.
- No source return, Sharpe ratio, drawdown, correlation, cost, or significance
  statistic is imported as a QM expectation or portfolio claim.

## Non-Duplicate Boundary

- QM5_12567 is a short-horizon long-only cumulative-RSI2 pullback family.
- QM5_12603 is standalone WTI trailing-12-month return-sign momentum.
- QM5_12733 ranks XTI/XNG on recent cumulative momentum.
- QM5_13115 ranks average returns from matching calendar months across years.
- QM5_13120 requires opposite XTI/XNG ranks at 12- and 18-month horizons.
- QM5_13121 uses synchronized trailing-12-month rank plus a seven-month trend
  confirmation.
- QM5_13126 interacts cumulative momentum with broker carry.
- No registry slug, strategy ID, card, SPEC, or EA source ranks XTI/XNG solely
  on the isolated return from the t-11 to t-10 month boundaries.

The canonical checker returned no exact or fuzzy match. Manual comparison of
signal input, window, transform, direction, cadence, and exit gives
CLEAN_AFTER_MANUAL_REVIEW before allocation.

## R1-R4

- R1 source: PASS with qualification. Complete Griffith institutional thesis
  chapter, exact reproducible pages and equations-by-construction, academic
  conference review, and later working-paper record; absence of journal review
  for the exact microscopic rule is explicit.
- R2 mechanical: PASS. Fixed t-11/t-10 endpoints, log return, higher-minus-
  lower rank, monthly paired hold, equal fixed risk, hard stops, and lifecycle
  guards are deterministic.
- R3 data: PASS for queue admission. Registered XTIUSD.DWX and XNGUSD.DWX have
  native D1 history; CFD/futures and roll-basis differences remain kill risks.
- R4 allowability: PASS. Native prices, calendar, ATR safety stops, and broker
  metadata only; no banned indicator, ML, external runtime feed, grid,
  martingale, pyramiding, or adaptive PnL fitting.

## Safety Boundary

No T_Live path, AutoTrading state, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized by this source
approval.
