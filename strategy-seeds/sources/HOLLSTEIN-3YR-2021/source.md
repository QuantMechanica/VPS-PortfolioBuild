---
source_id: HOLLSTEIN-3YR-2021
title: Anomalies in Commodity Futures Markets
publisher: Quarterly Journal of Finance
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-12
created: 2026-07-12
created_by: Research
uri: https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf
cards_extracted:
  - energy-trend36
---

# Hollstein-Prokopczuk-Tharann 36-Month Return Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-12 authorizes one new structural,
  low-frequency commodity/energy card, build, and Q02 enqueue.
- The complete 57-page accepted article and online appendix were read end to
  end on 2026-07-12: motivation, futures and options data, return construction,
  all anomaly definitions, portfolio tests, factor regressions, alternate
  portfolio counts, subperiods, annual holds, tables, and bibliography.
- This packet extracts only the source's 36-month average-return
  characteristic. Other characteristics in the paper are already represented
  or require unavailable option, equity-factor, futures-chain, or volume data.

## Primary Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017. DOI:
https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf

## Relevant Source Locations

- Accepted-manuscript pp. 5-10: 26-commodity sample, fixed-maturity futures
  spot-return construction, month-end sorts, minimum six available
  commodities, monthly rebalance, and collateralized long-short portfolios.
- pp. 14-15: the source-labelled 3-year-reversal characteristic produces a
  positive high-minus-low return; the 36-month result is only weakly
  significant and is explained by the equity four-factor model.
- Appendix B p. 28 (PDF p. 29): `3Y Reversal` is the average commodity-futures
  excess return over the prior 36 months.
- Table 4 Panel C (PDF p. 40): three-portfolio high-minus-low mean return is
  positive and weakly significant; the BGR alpha is significantly negative.
- Online Appendix Table A1 (PDF p. 46): the univariate cross-sectional
  36-month slope is positive but insignificant.
- Table A3 Panel C (PDF p. 49): the directly relevant two-portfolio spread is
  positive but insignificant; four- and five-portfolio evidence weakens.
- Table A4 Panel C (PDF p. 52): subperiod evidence is unstable and the paper's
  prose concludes that long-term reversal is overall unpriced.
- Table A5 Panel C (PDF p. 56): annual holding weakens the spread, supporting
  monthly rather than annual renewal.
- Table 1 (PDF p. 36) explicitly includes WTI crude oil and natural gas.

## Source Rule And Naming Boundary

At each month-end, the paper calculates each commodity's average futures
excess return over the prior 36 months, sorts the cross-section, buys the high
characteristic portfolio, shorts the low characteristic portfolio, and holds
for one month. Although the variable is named `3Y Reversal`, the tested and
reported direction is high-minus-low. Operationally that is 36-month relative
continuation, not contrarian reversal. The QM slug and title state the actual
direction rather than copying the source's potentially misleading label.

## Bounded Price-Native Translation

On the first tradable `XTIUSD.DWX` D1 bar of each broker month:

1. Reconstruct 37 consecutive completed broker-month-end closes for XTI and
   XNG from native D1 history.
2. Calculate exactly 36 monthly simple returns for each leg.
3. Compute the arithmetic average return for each leg.
4. Buy the higher-average-return leg and short the lower-average-return leg.
5. Split `RISK_FIXED=1000` equally, attach frozen ATR(20) times 3.5 hard stops,
   and close at the next month, after 40 days, or on an orphan/invalid package.

A missing calendar month, nonpositive close, nonfinite return, numerical tie,
invalid risk metadata, existing package, or prior entry in the same broker
month stays flat. The monthly direction, 36 observations, simple-return
arithmetic mean, equal fixed-risk halves, and no same-month re-entry are locked.

## Source Evidence Boundary

- The source ranks at least six of 26 fully collateralized futures; QM ranks
  only two continuous CFDs. Source breadth and diversification do not transfer.
- The paper carefully holds fixed-maturity futures and rolls before maturity.
  Darwinex continuous-CFD closes can mix roll, financing, and spot effects.
- Source excess returns include collateral conventions unavailable in the CFD
  price proxy. QM uses raw close-to-close simple returns and claims no exact
  replication.
- The source's directly relevant two-portfolio result and cross-sectional slope
  are insignificant. `expected_pf` is therefore a low queue-ordering prior.
- No source return, alpha, significance, cost, drawdown, correlation, or
  diversification statistic is imported as EA or portfolio evidence.

## Non-Duplicate Boundary

- `QM5_12386_comm-mom12m` and `QM5_13121_energy-tfmom` use 12-month momentum,
  not a 36-completed-month arithmetic-return rank.
- `QM5_13120_energy-momrev` requires a 12-month rank and an opposing 18-month
  rank; this card has one unconditional 36-month characteristic.
- `QM5_13123_energy-val-rank` compares current price with 54-66-month price
  anchors; it does not average monthly returns.
- `QM5_13148_energy-rank-lmh` compares fixed-origin normalized price levels;
  it has no rolling 36-month window.
- `QM5_12934_aa-comm-spot-rev-card` buys the one-year loser and shorts the
  winner across four commodities; this card buys the 36-month winner in a
  two-leg energy package.
- `QM5_12567_cum-rsi2-commodity` is a two-day long-only RSI pullback, not a
  monthly relative-trend basket.

The canonical checker found no exact identity collision and three expected
same-paper fuzzy matches (`energy-kurt-rank`, `energy-vov`, and
`xti-xng-lowmax`). Manual formula, direction, input, and horizon review found
no shared mechanic. Verdict: `FUZZY_SAME_SOURCE_MANUALLY_RESOLVED_DISTINCT`.

## R1-R4

- R1 source: PASS with weak-edge caveat. Peer-reviewed DOI, institutional
  accepted manuscript, complete article and online-appendix review.
- R2 mechanical: PASS. Fixed 36-month simple-return mean, monthly high-minus-
  low direction, equal fixed risk, hard stops, time exit, deal-history guard,
  and orphan cleanup are deterministic.
- R3 data: PASS for a disclosed proxy. Registered XTIUSD.DWX and XNGUSD.DWX D1
  history supplies completed month-end closes; futures/collateral fidelity is
  intentionally left for Q02 rejection or survival.
- R4 allowability: PASS. Native OHLC, ATR safety stops, calendar, deal history,
  and broker metadata only; no ML, banned indicator, external runtime feed,
  grid, martingale, pyramiding, or adaptive PnL fitting.

## Safety Boundary

No live setfile, T_Live path, AutoTrading action, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI change is authorized.
