---
source_id: HOLLSTEIN-MAX-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - xti-xng-lowmax
  - energy-kurt-rank
---

# Hollstein-Prokopczuk-Tharann Commodity MAX Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 57-page accepted article and online appendix were read end to
  end on 2026-07-11, including methodology, variable definitions, portfolio
  sorts, factor regressions, alternative portfolio splits, subperiods, annual
  holds, tables, and bibliography.
- The first extraction covers the paper's post-financialization negative
  MAX-return relation. The second covers its historical-kurtosis sort. Each is
  translated separately to a monthly XTI/XNG paired carrier; no other paper
  characteristic is approved by this packet.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017. DOI: https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Relevant Source Locations

- pp. 7-10: daily commodity returns, 12-month formation variables, monthly
  ranking, one-month hold, and fully collateralized long-short construction.
- p. 15 and Appendix B p. 29: MAX is the average of the five largest daily
  commodity-futures excess returns during the previous 12 months.
- pp. 23-25 and Online Appendix Table A4: the full-sample MAX spread is null,
  but the December 2000-December 2015 post-financialization spread is strongly
  negative.
- Table A3: alternative portfolio-count results; the full-sample two-portfolio
  MAX spread remains null and therefore is a material translation caveat.
- Table A5: annual holding periods weaken anomaly evidence; monthly renewal is
  the source-aligned baseline.
- Table 1: WTI crude oil and natural gas are explicit source instruments.

## Bounded Mechanization

At the first tradable D1 bar of each broker month, the EA loads 253 completed
D1 closes for `XTIUSD.DWX` and `XNGUSD.DWX`, calculates 252 simple daily
returns, takes the arithmetic mean of the five largest returns for each leg,
and calls that value MAX. It buys the lower-MAX leg, shorts the higher-MAX leg,
splits fixed package risk equally, and holds until the next month transition.

The source's full-sample result does not establish this edge. The direction is
based only on the paper's post-financialization subsample, which ends in 2015;
the QM 2017+ baseline is therefore a genuine out-of-sample falsification. The
paper ranks 26 collateralized futures and requires at least six available
commodities, whereas QM ranks two continuous CFDs. No source return, alpha,
correlation, or transaction-cost result is imported into the QM prior.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, pullback threshold, long-only
  state, or short holding period.
- Not `QM5_12733_xti-xng-xmom`: no cumulative-return winner rank.
- Not `QM5_12840_xti-xng-rspread`: no return-spread z-score or mean reversion.
- Not `QM5_12850_xti-xng-vcb`: no range compression or channel breakout.
- Not `QM5_13089_xti-xng-carry`: no broker-swap input.
- Not `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, `QM5_13121`,
  `QM5_13123`, or `QM5_13126`: no residual-volatility agreement,
  same-calendar return, skewness, reversal, trend, value, or carry signal.
- Not `QM5_13129_energy-rsj`: RSJ uses one completed month of separately
  squared positive and negative returns. MAX uses only the five largest daily
  returns over 252 observations and ignores downside semivariance.

Pre-allocation repository dedup verdict: `CLEAN` on 2026-07-11.

## R1-R4

- R1 source: PASS with explicit weak-evidence caveat. The primary source is a
  peer-reviewed article with DOI and institutional full text; only its modern
  subsample supports the direction.
- R2 mechanical: PASS. Fixed return count, exact top-five arithmetic mean,
  rank direction, monthly rebalance, equal fixed risk, hard stops, stale close,
  and orphan cleanup are deterministic.
- R3 data: PASS with translation risk. Registered XTIUSD.DWX and XNGUSD.DWX D1
  OHLC suffice; no futures chain or external feed is used.
- R4 deterministic/no ML: PASS. No ML, banned indicator, external runtime
  data, grid, martingale, or pyramiding is present.

## Second Extraction: Historical Kurtosis Rank

### Source Rule And Evidence

- pp. 9-10 define the month-end cross-sectional sort, one-month hold,
  fully-collateralized long-short construction, and minimum six-commodity
  source universe.
- p. 19 reports a positive full-sample relationship between historical
  kurtosis and next-month commodity returns.
- Appendix B p. 27 defines historical kurtosis from daily returns over the
  prior 12 months as the fourth central moment divided by the square of the
  sample variance. The source uses Pearson kurtosis, not excess kurtosis.
- Table 4 Panel F reports the full-sample three-portfolio high-minus-low
  result; Table A1 reports an insignificant Fama-MacBeth slope.
- Table A3 Panel F shows that the two-portfolio high-minus-low result is
  positive but insignificant, while four- and five-portfolio results weaken.
- Table A4 Panel F shows that the historical-kurtosis premium reverses sign
  and is insignificant in the December 2000-December 2015
  post-financialization subperiod.
- Table 1 includes both WTI crude oil and natural gas as source instruments.

### Bounded Mechanization

At the first tradable D1 bar of each broker month, calculate exactly 252 simple
daily returns for `XTIUSD.DWX` and `XNGUSD.DWX`. For each leg, compute the
arithmetic mean, sample variance with denominator 251, fourth central moment
with denominator 252, and Pearson historical kurtosis:

`kurtosis = fourth_central_moment / sample_variance^2`.

Buy the higher-kurtosis leg, short the lower-kurtosis leg, split fixed package
risk equally, and hold until the next month transition. A numerical tie,
nonpositive variance, incomplete history, or invalid arithmetic stays flat.

This is a strict carrier translation. The paper ranks at least six
collateralized futures and forms terciles; QM ranks only two continuous CFDs.
The directly relevant two-portfolio source result is insignificant, and the
modern source subperiod reverses sign. The 2017+ Q02 baseline is therefore a
falsification test with a deliberately low prior, not inherited evidence.

### Non-Duplicate Boundary

- `QM5_13118_energy-skew-rank` ranks the third standardized moment and buys
  lower skew; this extraction ranks the fourth standardized moment and buys
  higher kurtosis.
- `QM5_13129_energy-rsj` uses one month of separately squared positive and
  negative returns; historical kurtosis uses all 252 returns and a centered
  fourth moment.
- `QM5_13130_xti-xng-lowmax` averages only the five largest daily returns and
  buys the lower value; historical kurtosis uses the complete distribution and
  buys the higher value.
- `QM5_1212_carver-kurtsabs` and `QM5_1221_carver-kurtsrv` condition a skew
  direction on excess kurtosis with daily forecast scaling. This extraction
  uses no skew sign, forecast scalar, EMA, or daily state change.
- `QM5_10322_realized-moments` is a weekly intraday composite of volatility,
  skewness, and kurtosis; this extraction is a pure D1/monthly kurtosis rank.

Manual review resolves the dedup tool's expected same-source fuzzy match to
`QM5_13130`: the source lineage and carrier are shared, but the order statistic,
direction, distribution support, and source evidence are different. Verdict:
`CLEAN_AFTER_MANUAL_REVIEW` before allocation.

### R1-R4

- R1 source: PASS with strong negative translation caveats. Peer-reviewed DOI,
  institutional full text, complete article and appendix review.
- R2 mechanical: PASS. Fixed 252-return Pearson-kurtosis formula, monthly rank,
  equal fixed risk, hard stops, time exit, and orphan cleanup.
- R3 data: PASS with narrow-carrier risk. Registered XTI/XNG D1 OHLC suffices;
  no futures chain, options, volume, or external feed is used.
- R4 deterministic/no ML: PASS. No ML, banned indicator, grid, martingale,
  pyramiding, or adaptive PnL logic.
