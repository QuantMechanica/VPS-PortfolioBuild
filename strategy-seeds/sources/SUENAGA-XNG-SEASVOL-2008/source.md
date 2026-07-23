# SUENAGA-XNG-SEASVOL-2008

## Approval And Review

- Mission-directed source approval: 2026-07-10 commodity/energy sleeve mission.
- Full source reviewed: all 26 pages, including the POTS specification, data,
  estimation results, hedging application, conclusion, and bibliography.
- Research use: structural volatility-seasonality lineage only. The paper does
  not publish a directional trading strategy and assumes martingale daily price
  changes in its hedging derivation.

## Primary Source

Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C. (2008), "Volatility
Dynamics of NYMEX Natural Gas Futures Prices," *Journal of Futures Markets*
28(5), 438-463. DOI `10.1002/fut.20317`.

- Author-hosted full paper:
  https://files.asmith.ucdavis.edu/2008_JFutMkt_SSW_NGfutures.pdf
- Journal DOI: https://doi.org/10.1002/fut.20317

## Findings Used

- Daily natural-gas futures volatility varies materially with both season and
  time to maturity.
- The paper identifies two broad information/volatility windows: early May to
  late September, and early November to mid-January.
- Storage capacity, seasonal demand, and the limited ability of inventory to
  buffer shocks provide the physical-market explanation.
- The continuous `XNGUSD.DWX` CFD cannot reproduce the paper's contract-month
  panel, maturity-specific loadings, or optimal hedge portfolio. The card uses
  only the common timing implication and lets an H4 close determine direction.

## Translation Boundary

The paper is not evidence that a prior-range breakout is profitable. The QM
rule is an explicit, falsifiable mechanization of a volatility forecast:
one close-confirmed H4 breakout of the previous completed D1 range per week
during the source windows. No POTS/GARCH/Kalman model, futures curve, contract
selection, external feed, or source performance number is imported.

A second bounded card, `xng-seas-trend`, combines the same source timing gate
with the peer-reviewed Moskowitz-Ooi-Pedersen own-past-return trend mechanic.
It is monthly D1 rather than weekly H4, and it exits when the source window
ends. The source still does not establish directional profitability.

## Source Verdict

- R1: PASS — peer-reviewed named-author paper with DOI and author-hosted PDF.
- R2: PASS — the QM translation is deterministic and its source/proxy gap is
  explicit.
- R3: PASS — `XNGUSD.DWX` H4 and D1 history are registered locally.
- R4: PASS — no ML, grid, martingale, pyramiding, or external runtime data.
